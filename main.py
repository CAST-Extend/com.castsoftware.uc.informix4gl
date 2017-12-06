import cast_upgrade_1_5_14 # @UnusedImport
import cast.analysers.ua
from cast.analysers import log, Bookmark
import os
import re
#import tempfile

class Informix4GLSrcFile(cast.analysers.ua.Extension):
    def start_file(self, file):             # Extension point : each file
        filepath=file.get_path()
        if not filepath.endswith('.4gl') and not filepath.endswith('.per'):   # UA is supposed to filter only *.bat , this check is in double
            return
        
        #create/open link file
        #TODO: tempfile.gettempdir() is not working in CMS!
        # linksFile = open("%s\Informix4GL_linksFile.txt" % tempfile.gettempdir(), "a+")
        linksFile = open("C:\Temp\Informix4GL_linksFile.txt", "a+")
        
        
        if filepath.endswith('.per'): #a screen. create object and that's it
            screenObject = cast.analysers.CustomObject()
            screenObject.set_name(os.path.basename(filepath)[:-4])
            screenObject.set_fullname("%s/%s" % (filepath, screenObject.name))
            screenObject.set_type('INFORMIX4GLScreen')
            screenObject.set_parent(file)
            screenObject.save()
            
            lineNb = 0
            with open(file.get_path(), 'r') as f:
                for line in f:
                    lineNb +=1
            screenObject.save_position(Bookmark(file, 1, 1, lineNb, 1))
            #log.info("SCREEN: %s" % screenObject.fullname)
        
        if filepath.endswith('.4gl'): #
            programObject = cast.analysers.CustomObject()
            programObject.set_name(os.path.basename(filepath)[:-4])
            programObject.set_fullname("%s/%s" % (filepath, programObject.name))
            programObject.set_type('INFORMIX4GLProgram')
            programObject.set_parent(file)
            programObject.save()
            #log.info("PROGRAM: %s" % programObject.fullname)
        
            # parsing line by line
            mainSection = None
            mainSectionLineNbr = 1
            menuSection = None
            menuSectionLineNbr = 1
            functionSection = None
            functionSectionLineNbr = 1
            
            lineNb = 0
            with open(file.get_path(), 'r') as f:
                for line in f:
                    lineNb +=1
                    
                    if mainSection is not None or menuSection is not None or functionSection is not None:
                        if menuSection is not None:
                            callerFullName = menuSection.fullname
                            callerShortName = menuSection.name
                        else: 
                            if mainSection is not None:
                                callerFullName = mainSection.fullname
                                callerShortName = mainSection.name
                            else:
                                callerFullName = functionSection.fullname
                                callerShortName = functionSection.name
                        
                        matchObj = re.match("^[ \t]*CALL[ \t]+([^(]+)\(", line)
                        if matchObj:
                            calledShortName = matchObj.group(1)
                            colStart = line.find(calledShortName) + 1
                            colEnd = colStart + len(calledShortName)
                            #log.info("[%d][%d-%d] CALL Link to %s from %s" % (lineNb, colStart, colEnd, calledShortName, callerFullName))
                            linksFile.write("%s|%s|callLink|%s|%s|%s|%d|%d|%d\n" % (filepath, programObject.name, callerShortName, callerFullName, calledShortName, lineNb, colStart, colEnd))                               
                        
                        matchObj = re.match('^[ \t]*OPEN FORM[ \t]+[^"]+"([^"]+)', line)
                        if matchObj:
                            calledShortName = matchObj.group(1)
                            colStart = line.find('"%s"' %calledShortName) + 2
                            colEnd = colStart + len(calledShortName)
                            #log.info("[%d][%d-%d] OPEN FORM Link to %s from %s" % (lineNb, colStart, colEnd, calledShortName, callerFullName))
                            linksFile.write("%s|%s|screenLink|%s|%s|%s|%d|%d|%d\n" % (filepath, programObject.name, callerShortName, callerFullName, calledShortName, lineNb, colStart, colEnd))                               
                        
                    #log.info("|%s|" % line)
                    if re.match("^[ \t]*GLOBALS[ \t]+", line):
                        globalsSection = cast.analysers.CustomObject()
                        
                        #Extract Name
                        matchObj = re.match("^[ \t]*GLOBALS[ \t]+\"([^\"]+)", line)
                        if matchObj:
                            globalsSection.set_name(matchObj.group(1))
                        else:
                            globalsSection.set_name("undefined")
                            log.warning("[%d] a GLOBAL has no name!" % lineNb)

                        globalsSection.set_fullname("%s/%s" % (programObject.fullname, globalsSection.name))
                        globalsSection.set_type('INFORMIX4GLGlobals')
                        globalsSection.set_parent(programObject) #programObject
                        globalsSection.save()
                        #log.info("GLOBALS: %s" % globalsSection.fullname)
                        globalsSection.save_position(Bookmark(file, lineNb, 1, lineNb, len(line))) 
                    
                    if re.match("^[ \t]*MAIN[ \t]*$", line):
                        #log.debug("[%d] New MAIN section" % lineNb)
                        if mainSection is not None:
                            log.warning("[%d] a MAIN section is already opened!" % lineNb)
                        else:                            
                            mainSection = cast.analysers.CustomObject()
                            mainSection.set_name("MAIN")
                            mainSection.set_fullname("%s/%s" % (programObject.fullname, mainSection.name))
                            mainSection.set_type('INFORMIX4GLMain')
                            mainSection.set_parent(programObject) #programObject
                            mainSection.save()
                            #log.info("MAIN: %s" % mainSection.fullname)
                            mainSectionLineNbr = lineNb
                    
                    if re.match("^[ \t]*END MAIN[ \t]*$", line):
                        #log.debug("[%d] End of MAIN section" % lineNb)
                        if mainSection is not None:
                            mainSection.save_position(Bookmark(file, mainSectionLineNbr, 1, lineNb, 1))                            
                            mainSection = None
                    
                    if re.match("^[ \t]*MENU[ \t]+", line):
                        #log.debug("[%d] New MENU section" % lineNb)
                        if menuSection is not None:
                            log.warning("[%d] a MENU section is already opened!" % lineNb)
                        else:                            
                            menuSection = cast.analysers.CustomObject()
                            #Find parent
                            if mainSection is not None:
                                menuSection.set_parent(mainSection)
                            else:
                                if functionSection is not None:
                                    menuSection.set_parent(functionSection)
                                else:
                                    menuSection.set_parent(programObject)
                            
                            #Extract Name
                            matchObj = re.match("^[ \t]*MENU[ \t]+\"([^\"]+)", line)
                            if matchObj:
                                menuSection.set_name(matchObj.group(1))
                            else:
                                menuSection.set_name("undefined")  
                                log.warning("[%d] a MENU has no name!" % lineNb)                          
                            
                            menuSection.set_fullname("%s/%s" % (menuSection.parent.fullname, menuSection.name))
                            menuSection.set_type('INFORMIX4GLMenu')
                            menuSection.save()
                            #log.info("MENU: %s" % menuSection.fullname)
                            menuSectionLineNbr = lineNb
                    
                    if re.match("^[ \t]*END MENU[ \t]*$", line):
                        #log.debug("[%d] End of MENU section" % lineNb)
                        if menuSection is not None:                            
                            menuSection.save_position(Bookmark(file, menuSectionLineNbr, 1, lineNb, 1))                            
                            menuSection = None
                    
                    if re.match("^[ \t]*FUNCTION[ \t]+", line):
                        #log.debug("[%d] New FUNCTION %s" % (lineNb, name))
                        if functionSection is not None:
                            log.warning("[%d] a FUNCTION section is already opened!" % lineNb)
                        else:                            
                            functionSection = cast.analysers.CustomObject()
                            
                            #Extract function name
                            matchObj = re.match("^[ \t]*FUNCTION[ \t]+([^(]+)\(", line)
                            if matchObj:
                                functionSection.set_name(matchObj.group(1))
                            else:
                                functionSection.set_name("undefined")
                                log.warning("[%d] a FUNCTION has no name!" % lineNb)

                            functionSection.set_fullname("%s/%s" % (programObject.fullname, functionSection.name))
                            functionSection.set_type('INFORMIX4GLFunction')
                            functionSection.set_parent(programObject) #programObject
                            functionSection.save()
                            #log.info("FUNCTION: %s" % functionSection.fullname)
                            functionSectionLineNbr = lineNb 
                    
                    if re.match("^[ \t]*END FUNCTION[ \t]*", line):
                        #log.debug("[%d] End of FUNCTION section" % lineNb)
                        if functionSection is not None:
                            functionSection.save_position(Bookmark(file, functionSectionLineNbr, 1, lineNb, 1))                            
                            functionSection = None
            
            programObject.save_position(Bookmark(file, 1, 1, lineNb, 1))
            linksFile.close()