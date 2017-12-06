'''
Created on Dec 5, 2017

@author: JGD
'''
import unittest
from cast.application.test import run

class Test(unittest.TestCase):


    def testName(self):
        run(kb_name='informix4gl_local', application_name='Informix 4GL')


if __name__ == "__main__":
    unittest.main()