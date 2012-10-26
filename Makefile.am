COUCHBASE_PYTHON_LIB = ../couchbase-python-client/couchbase \
                       ../couchbase-python-client/httplib2 \
                       ../couchbase-python-client/simplejson \
                       ../couchbase-python-client/uuid.py

default:

bindir=$(DESTDIR)$(localbindir)

pythonlibdir=$(libdir)/python

pythonlib_SCRIPTS= cbdocloader

PYTHON_TOOLS= wrapper/cbdocloader

sample_FILES= beer-sample.zip gamesim-sample.zip

${PYTHON_TOOLS}: wrapper/wrapper
	cp $< $@

CLEANFILES = ${PYTHON_TOOLS}
bin_SCRIPTS = ${PYTHON_TOOLS}

EXTRA_DIST = $(pythonlib_SCRIPTS) $(sample_FILES)

install-data-hook:
	if test ! "$(mkdir_p)" = ""; then \
	    $(mkdir_p) "$(DESTDIR)$(localstatedatdir)"; \
	else \
	    echo "WARNING: You may have to create these directories by hand."; \
	    mkdir -p "$(DESTDIR)$(localstatedatdir)"; \
	fi
	cp -rf $(COUCHBASE_PYTHON_LIB) $(pythonlibdir) && \
	cp *.zip $(DESTDIR)$(localstatedatdir)


