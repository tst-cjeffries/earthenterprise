// gepublishmanagerhelper.i - SWIG interface.

%module libgepublishmanagerhelper

%include <std_string.i>
%include <std_vector.i>

%{
#include "fusion/gepublish/gepublishmanagerhelper.h"
%}

// Instantiate templates used by gepublishmanagerhelper.
namespace std {
%template(ManifestEntryVector) vector<ManifestEntry>;
}

// Include header file with the above prototypes.
%include common/ManifestEntry.h
%include fusion/gepublish/gepublishmanagerhelper.h

