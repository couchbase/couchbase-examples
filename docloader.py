#!/usr/bin/env python
# -*- python -*-

import sys, zipfile, os, os.path
import getopt
import json
import ast
import tempfile

from couchbase import client

def usage(err=0):
    print >> sys.stderr, """
Usage: %s [-u user [-p password]] [-n host:port] [-b bucket] <directory>|zipfile

Example:
  %s -u user -p secret9876 localhost:8091 default mydir 
""" % (os.path.basename(sys.argv[0]), (os.path.basename(sys.argv[0])))
    sys.exit(err)

def parse_args(args):
    user = None
    pswd = None
    host = 'localhost:8091'
    bucket = 'default'

    try:
        opts, args = getopt.getopt(args, 'hu:p:n:b:', ['help'])
    except getopt.GetoptError, e:
        usage("ERROR: " + e.msg)

    for (o, a) in opts:
        if o == '--help' or o == '-h':
            usage()
        elif o == '-u':
            user = a
        elif o == '-p':
            pswd = a
        elif o == '-n':
            host = a
        elif o == '-b':
            bucket = a
        else:
            usage("ERROR: unknown option - " + o)

    if not args or len(args) < 1:
        usage("ERROR: missing upload directory or zipped file.")

    return user, pswd, host, bucket, args

def save_doc(bucket,fp, views):
    buf = fp.read()
    result = ast.literal_eval(buf)
    if isinstance(result, dict):
        try:
            doc_id = bucket.save(result)
        except:
            doc_id = "_design/testing"
        if result['_id'] and 'views' in result:
            for key in result['views'].iterkeys():
                viewpath = result['_id'] + '/_view/' + key
                views.append(viewpath)

def listFiles(bucket, dir, views):
    basedir = dir
    print "Files in ", os.path.abspath(dir), ": "
    subdirlist = []
    for item in os.listdir(dir):
        if os.path.isfile(os.path.join(basedir, item)):
            with open(os.path.join(basedir, item), 'r') as fp:
                #print item
                save_doc(bucket, fp, views)
        else:
            subdirlist.append(os.path.join(basedir, item))
    for subdir in subdirlist:
        listFiles(bucket, subdir, views)

def unzip_file_and_upload(bucket,file, views):
    zfobj = zipfile.ZipFile(file)
    for name in zfobj.namelist():
        if name.endswith('/'):
            print "dir:", name
        else:
            #print 'file:', name
            temp = tempfile.NamedTemporaryFile(delete=False)
            fname = temp.name
            temp.write(zfobj.read(name))              
            temp.close()
            with open(fname, 'r') as fp:
                save_doc(bucket, fp, views)
            os.remove(fname)
            
def populate_docs(bucket, dir, views):
    if dir.endswith('.zip'):
        unzip_file_and_upload(bucket, dir, views)
    else:
        listFiles(bucket, dir, views)

def main():
    user, pswd, host, bucket, args = parse_args(sys.argv[1:])

    cb = client.Server(host, user, pswd)

    try:
        newbucket = cb.create(bucket, ram_quota_mb=100, replica=1)
    except:
        newbucket = cb[bucket]

    #upload documents
    dir = args[0]
    views = []
    populate_docs(newbucket, dir, views)

    # execute views at least once
    for viewpath in views:
        rows = newbucket.view(viewpath)
        for row in rows:
            print row
    
if __name__ == '__main__': main()
