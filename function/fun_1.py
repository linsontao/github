#!/bin/env python
'''
def max_int(*num):
    return max(num)


print max_int(37,3,12,244,232,121,55,34,23)


def max_len(*s):
    return max(s,key=len)


print max_len('addf','sfds','abcdevd','cde','gg','sfsdf','abdfddd')


def get_doc(m):
    module =  __import__(m)
    return module.__doc__


print get_doc('urllib')

def get_text(f):
    f1 = open(f)
    context=f1.readlines()
    f1.close()
    print  context

get_text('/root/install.log')
'''

def get_dir(folder):
    import glob
    if folder[-1] == '/':
        folder += '*'
    if folder[-1] != '/':
        folder += '/*'
    return glob.glob(folder)



print get_dir('/root')
print get_dir('/root/')
