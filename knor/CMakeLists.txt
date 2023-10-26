cmake_minimum_required(VERSION 3.14)

project(knor
    VERSION 1.0.0
    DESCRIPTION "Knor, a synthesis tool for HOA parity automata using BDDs"
    HOMEPAGE_URL "https://github.com/trolando/knor"
    LANGUAGES C CXX
)

find_package(oink)
find_package(sylvan)
set (READLINE_FOUND FALSE)
add_definitions (-DABC_USE_STDINT_H)
add_subdirectory("abc" EXCLUDE_FROM_ALL)

# Parser generator
find_package(FLEX)
find_package(BISON)
FLEX_TARGET(hoalexer src/hoa.l ${CMAKE_CURRENT_BINARY_DIR}/hoalexer.c DEFINES_FILE ${CMAKE_CURRENT_BINARY_DIR}/hoalexer.h)
BISON_TARGET(hoaparser src/hoa.y ${CMAKE_CURRENT_BINARY_DIR}/hoaparser.c DEFINES_FILE ${CMAKE_CURRENT_BINARY_DIR}/hoaparser.h)
ADD_FLEX_BISON_DEPENDENCY(hoalexer hoaparser)

# Knor itself
add_executable(knor)
target_sources(knor
  PRIVATE
    src/knor.cpp
    src/symgame.cpp
    src/bisim.cpp
    src/aigmaker.cpp
    src/simplehoa.c
    src/aiger.c
    ${BISON_hoaparser_OUTPUTS}
    ${FLEX_hoalexer_OUTPUTS}
)
target_compile_features(knor PUBLIC c_std_11 cxx_std_11)
target_compile_options(knor PRIVATE -Wall -Wextra -fno-strict-aliasing -Wno-deprecated -Wno-unused-parameter)
target_link_libraries(knor PRIVATE oink sylvan::sylvan libabc "-static")
target_include_directories(knor PRIVATE src)
