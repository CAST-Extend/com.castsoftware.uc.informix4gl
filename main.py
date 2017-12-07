import cast_upgrade_1_5_14 # @UnusedImport
import cast.analysers.ua
from cast.analysers import log, Bookmark, external_link, create_link
import os
import re

class Informix4GLSrcFile(cast.analysers.ua.Extension):
    def start_file(self, file):             # Extension point : each file
        filepath=file.get_path()
        if not filepath.endswith('.4gl') and not filepath.endswith('.per'):
            return
        
        #create/open link file
        linksFile = self.get_intermediate_file("Informix4GL_linksFile.txt")        
        
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
            
            activeSection = None
            
            sqlLineNbr = 1
            sql = ""
            statementNbr = 1
            
            inMultilineComment = False
            
            lineNb = 0
            with open(file.get_path(), 'r') as f:
                for line in f:
                    lineNb +=1
                    
                    #Commented-out Line
                    if re.match("^[ \t]*--", line):
                        continue
                    
                    if re.match("^[ \t]*{", line):
                        inMultilineComment = True
                    
                    if inMultilineComment:
                        if re.match("^[ \t]*}", line) or re.match("}[ \t]*$", line):
                            inMultilineComment = False
                        continue
                    
                    if activeSection is not None:                        
                        #Links to functions
                        matchObj = re.search('([^ =\(]+)\(', line)
                        if matchObj:
                            calledShortName = matchObj.group(1)
                            colStart = line.find(calledShortName) + 1
                            colEnd = colStart + len(calledShortName)
                            #log.info("[%d][%d-%d] CALL Link to %s from %s" % (lineNb, colStart, colEnd, calledShortName, callerFullName))
                            linksFile.write("%s|%s|callLink|%s|%s|%s|%d|%d|%d\n" % (filepath, programObject.name, activeSection.name, activeSection.fullname, calledShortName, lineNb, colStart, colEnd))                               
                        
                        #Links to Screens
                        matchObj = re.match('^[ \t]*OPEN FORM[ \t]+[^"]+"([^"]+)', line)
                        if matchObj:
                            calledShortName = matchObj.group(1)
                            colStart = line.find('"%s"' %calledShortName) + 2
                            colEnd = colStart + len(calledShortName)
                            #log.info("[%d][%d-%d] OPEN FORM Link to %s from %s" % (lineNb, colStart, colEnd, calledShortName, callerFullName))
                            linksFile.write("%s|%s|screenLink|%s|%s|%s|%d|%d|%d\n" % (filepath, programObject.name, activeSection.name, activeSection.fullname, calledShortName, lineNb, colStart, colEnd))                               
                    
                    #Identify embedded SQL    
                    if re.match("^[ \t]*(SELECT|UPDATE|INSERT|DELETE)[ \t]+", line):
                        sql = line
                        sqlLineNbr = lineNb
                        
                    if sql != "":
                        mO1 = re.match("^[ \t]*$", line)
                        mO2 = re.match("^[ \t]*(CALL|COMMIT|CONTINUE|DISPLAY|ELSE|END|ERROR|EXECUTE|EXIT|FOR|IF|LET|MENU|NEXT|PREPARE|RETURN|ROLLBACK)[ \t]+", line)
                        if mO1 or mO2:
                            sqlquery = cast.analysers.CustomObject()
                            sqlquery.set_name("statement %d" % statementNbr)
                            statementNbr += 1
                            sqlquery.set_type('CAST_SQL_NamedQuery')
                            sqlquery.set_parent(activeSection)
                            sqlquery.save()
                            #log.info("SQL: %s" % sqlquery.fullname)
                            
                            sqlquery.save_position(Bookmark(file, sqlLineNbr, 1, lineNb-1, len(line))) 
                            
                            sqlquery.save_property('CAST_SQL_MetricableQuery.sqlQuery', sql)
                            log.debug(' - creating sql links...')
                            for embedded in external_link.analyse_embedded(sql):
                                for t in embedded.types:
                                    #log.info(' - link to : %s' % embedded.callee.get_name())
                                    link = create_link(t, sqlquery, embedded.callee)
                                    link.mark_as_not_sure()
            
                            sql = ""
                        else:
                            sql += line
                    
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
                        statementNbr = 1
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
                            
                            activeSection = mainSection
                    
                    if re.match("^[ \t]*END MAIN[ \t]*$", line):
                        #log.debug("[%d] End of MAIN section" % lineNb)
                        if mainSection is not None:
                            mainSection.save_position(Bookmark(file, mainSectionLineNbr, 1, lineNb, len(line)))                            
                            mainSection = None
                            
                            activeSection = None
                    
                    if re.match("^[ \t]*MENU[ \t]+", line):
                        statementNbr = 1
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
                            
                            activeSection = menuSection
                    
                    if re.match("^[ \t]*END MENU[ \t]*$", line):
                        #log.debug("[%d] End of MENU section" % lineNb)
                        if menuSection is not None:                            
                            menuSection.save_position(Bookmark(file, menuSectionLineNbr, 1, lineNb, len(line)))                            
                            activeSection = menuSection.parent
                            menuSection = None
                    
                    if re.match("^[ \t]*FUNCTION[ \t]+", line):
                        statementNbr = 1
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
                            
                            activeSection = functionSection
                    
                    if re.match("^[ \t]*END FUNCTION[ \t]*", line):
                        #log.debug("[%d] End of FUNCTION section" % lineNb)
                        if functionSection is not None:
                            functionSection.save_position(Bookmark(file, functionSectionLineNbr, 1, lineNb, len(line)))                            
                            functionSection = None
                            
                            activeSection = None
            
            programObject.save_position(Bookmark(file, 1, 1, lineNb, 1))