Docloader
=============

We use this tool to upload a bunch of json documents into Couchbase Server.

Build
-------

After you clone the project from `git@github.com:couchbase/couchbase-examples.git`, run the following command:

    config/autorun.sh

To build the package, run

    make bdist

Run command
------------

    cbdocloader OPTIONS DOCUMENTS

DOCUMENTS:

The documents parameter can be either a directory name which contains all the json documents or a .zip file which archives the document directory.

Generally speaking, the document directory should have the following layout:

    /design_docs    which contains all the design docs for views.
    /docs           which contains all the raw json data files. It can have other sub directories too.

All json files should be well formatted. And no spaces allowed in file names. Design docs will be uploaded after all other data files.

OPTIONS:

  `-n HOST[:PORT]`, --node=HOST[:PORT] Default port is 8091

  `-u USERNAME`, --user=USERNAME       REST username of the cluster. It can be specified in environment variable REST_USERNAME.

  `-p PASSWORD`, --password=PASSWORD   REST password of the cluster. It can be specified in environment variable REST_PASSWORD.

  `-b BUCKETNAME`, --bucket=BUCKETNAME Specific bucket name. Default is default bucket. Bucket will be created if it doesn't exist.

  `-s QUOTA`,                          RAM quota for the bucket. Unit is MB. Default is 100MB.

  `-h` --help                          Show this help message and exit

Example
-------

    # Upload documents archived in zip file ../samples/gamesim.zip. All data will be inserted in bucket mybucket
    #
    ./cbdocloader  -n localhost:8091 -u Administrator -p password -b mybucket ../samples/gamesim.zip

Errors
------

These are kinds of error cases to consider ...

* JSON files are not well formatted
* Wrong REST username and password
* Bucket cannot be created due to too large ram quota specified.

Licenses
--------

### Beer sample

To quote from the original [Open Beer Database](http://openbeerdb.com/):

    This Open Beer Database is made available under the Open Database License:
    http://opendatacommons.org/licenses/odbl/1.0/. Any rights in individual
    contents of the database are licensed under the Database Contents License:
    http://opendatacommons.org/licenses/dbcl/1.0/

The data was converted to JSON with the [scripts from Sergey Avseyev](https://github.com/avsej/beer-sample).

### Gamesim sample

The gamesim sample is licensed under the Apache License 2.0.
