PROJECT(CouchbasePythonClient)
CMAKE_MINIMUM_REQUIRED(VERSION 2.8)

# Generate the python wrappers
CONFIGURE_FILE (${CMAKE_CURRENT_SOURCE_DIR}/wrapper/wrapper
                ${CMAKE_CURRENT_BINARY_DIR}/wrapper/cbdocloader)

INSTALL(PROGRAMS
        ${CMAKE_CURRENT_BINARY_DIR}/wrapper/cbdocloader
        DESTINATION bin)

INSTALL(PROGRAMS
        cbdocloader
        DESTINATION lib/python)

INSTALL(FILES
        beer-sample.zip
        gamesim-sample.zip
        DESTINATION samples)
