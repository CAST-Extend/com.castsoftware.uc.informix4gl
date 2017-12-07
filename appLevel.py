'''
Created on Dec 6, 2017

@author: JGD
'''
import cast_upgrade_1_5_14 # @UnusedImport
from cast.application import ApplicationLevelExtension, create_link, Bookmark
import logging

class ApplicationExtension(ApplicationLevelExtension):

    def end_application(self, application):
        logging.info('Creating links for Informix 4GL...')
        
        previousFileName = ""
        with self.get_intermediate_file("Informix4GL_linksFile.txt") as f:
            for line in f:
                fileName, programName, linkType, callerShortName, callerFullName, calledShortName, lineNbr, colStart, colEnd = line.split('|')
                #logging.info("%s to %s" % (linkType, callerFullName))
                
                #Get Caller Program                
                if previousFileName != fileName:  
                    for fo in application.get_files(): #TODO Need to filter better here but languages did not work
                        if fo.get_fullname() == fileName:
                            fileObj = fo
                                   
                    callerProgramObj = None
                    for o in application.get_objects_by_name(name=programName):
                        if o.get_fullname().startswith(fileName):
                            callerProgramObj = o
                            callerProgramObj.load_children()
                            #logging.info(" -p %s" % callerProgramObj.get_fullname())
                
                #Get Caller Object 
                callerObj = None
                for o in application.get_objects_by_name(name=callerShortName):
                    if o.get_fullname() == callerFullName:
                        callerObj = o
                        #logging.info(" -r %s" % callerObj.get_fullname())
                
                #Get Called Object
                calledObj = None
                if linkType == "callLink":
                    calledObjList = application.get_objects_by_name(name=calledShortName)
                    for o in calledObjList:
                        if o.get_fullname().startswith(fileName):
                            calledObj = o
                            #logging.info(" -d %s" % calledObj.get_fullname())
                    
                    if calledObj is None:
                        for o in calledObjList:
                            for o in callerProgramObj.get_children():
                                if o.get_type() == "INFORMIX4GLGlobals" and o.get_fullname().contains(o.get_name()):
                                    calledObj = o
                                    #logging.info(" -D %s" % (calledObj.get_name()))
                
                if linkType == "screenLink":
                    for o in application.search_objects(name=calledShortName, category="INFORMIX4GLScreen"):
                        calledObj = o
                        #logging.info(" -d %s" % calledObj.get_fullname())
                
                if callerObj is None:
                    logging.warning("%s could not be found in the KB!" % callerFullName)
                else:
                    if calledObj is None:
                        #The regex catches lots of things that are not functions to begin with...
                        #no need for it to be a warning
                        logging.debug("%s could not be found in the KB!" % calledShortName)
                    else:
                        logging.debug("create link from %s to %s" % (callerObj.get_fullname(), calledObj.get_fullname()))
                        link = create_link('callLink', callerObj, calledObj, Bookmark(fileObj, lineNbr, colStart, lineNbr, colEnd))
                        link.mark_as_not_sure()
                
                previousFileName = fileName        