set(LIBFIDO2_LIBRARY "${CMAKE_CURRENT_LIST_DIR}/lib/libfido2.a")
set(LIBFIDO2_LIBRARIES "${LIBFIDO2_LIBRARY};cbor;crypto;z;-framework CoreFoundation;-framework IOKit")
set(LIBFIDO2_INCLUDE_DIR "${CMAKE_CURRENT_LIST_DIR}/include")
set(LIBFIDO2_INCLUDE_DIRS "${LIBFIDO2_INCLUDE_DIR}")

if(NOT TARGET fido2)
  add_library(fido2 STATIC IMPORTED)

  set_target_properties(fido2 PROPERTIES
    IMPORTED_LOCATION "${LIBFIDO2_LIBRARY}"
    INTERFACE_INCLUDE_DIRECTORIES "${LIBFIDO2_INCLUDE_DIRS}"
    INTERFACE_LINK_LIBRARIES "cbor;crypto;z;-framework CoreFoundation;-framework IOKit"
  )
endif()

if(NOT TARGET libfido2::fido2)
  add_library(libfido2::fido2 STATIC IMPORTED)

  set_target_properties(libfido2::fido2 PROPERTIES
    IMPORTED_LOCATION "${LIBFIDO2_LIBRARY}"
    INTERFACE_INCLUDE_DIRECTORIES "${LIBFIDO2_INCLUDE_DIRS}"
    INTERFACE_LINK_LIBRARIES "cbor;crypto;z;-framework CoreFoundation;-framework IOKit"
  )
endif()

set(FIDO2_FOUND TRUE)
set(LIBFIDO2_FOUND TRUE)
set(libfido2_FOUND TRUE)
