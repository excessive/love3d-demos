local ffi = require "ffi"

local already_loaded = pcall(ffi.new, "struct iqmheader")
if already_loaded then
	return ffi.C
end

ffi.cdef([[
// IQM: Inter-Quake Model format
// version 1: April 20, 2010
// version 2: May 31, 2011
//    * explicitly store quaternion w to minimize animation jitter
//      modified joint and pose struct to explicitly store quaternion w in new channel 6 (with 10 total channels)

// all data is little endian

typedef uint32_t uint;
typedef uint8_t uchar;
typedef uint8_t byte; // simplifies translation for LOVE.

struct iqmheader
{
    char magic[16]; // the string "INTERQUAKEMODEL\0", 0 terminated
    uint version; // must be version 2
    uint filesize;
    uint flags;
    uint num_text, ofs_text;
    uint num_meshes, ofs_meshes;
    uint num_vertexarrays, num_vertexes, ofs_vertexarrays;
    uint num_triangles, ofs_triangles, ofs_adjacency;
    uint num_joints, ofs_joints;
    uint num_poses, ofs_poses;
    uint num_anims, ofs_anims;
    uint num_frames, num_framechannels, ofs_frames, ofs_bounds;
    uint num_comment, ofs_comment;
    uint num_extensions, ofs_extensions; // these are stored as a linked list, not as a contiguous array
};
// ofs_* fields are relative to the beginning of the iqmheader struct
// ofs_* fields must be set to 0 when the particular data is empty
// ofs_* fields must be aligned to at least 4 byte boundaries

struct iqmmesh
{
    uint name;     // unique name for the mesh, if desired
    uint material; // set to a name of a non-unique material or texture
    uint first_vertex, num_vertexes;
    uint first_triangle, num_triangles;
};

// all vertex array entries must ordered as defined below, if present
// i.e. position comes before normal comes before ... comes before custom
// where a format and size is given, this means models intended for portable use should use these
// an IQM implementation is not required to honor any other format/size than those recommended
// however, it may support other format/size combinations for these types if it desires
enum // vertex array type
{
    IQM_POSITION     = 0,  // float, 3
    IQM_TEXCOORD     = 1,  // float, 2
    IQM_NORMAL       = 2,  // float, 3
    IQM_TANGENT      = 3,  // float, 4
    IQM_BLENDINDEXES = 4,  // ubyte, 4
    IQM_BLENDWEIGHTS = 5,  // ubyte, 4
    IQM_COLOR        = 6,  // ubyte, 4

    // all values up to IQM_CUSTOM are reserved for future use
    // any value >= IQM_CUSTOM is interpreted as CUSTOM type
    // the value then defines an offset into the string table, where offset = value - IQM_CUSTOM
    // this must be a valid string naming the type
    IQM_CUSTOM       = 0x10
};

enum // vertex array format
{
    IQM_BYTE   = 0,
    IQM_UBYTE  = 1,
    IQM_SHORT  = 2,
    IQM_USHORT = 3,
    IQM_INT    = 4,
    IQM_UINT   = 5,
    IQM_HALF   = 6,
    IQM_FLOAT  = 7,
    IQM_DOUBLE = 8,
};

struct iqmvertexarray
{
    uint type;   // type or custom name
    uint flags;
    uint format; // component format
    uint size;   // number of components
    uint offset; // offset to array of tightly packed components, with num_vertexes * size total entries
                 // offset must be aligned to max(sizeof(format), 4)
};

struct iqmtriangle
{
    uint vertex[3];
};

struct iqmadjacency
{
    // each value is the index of the adjacent triangle for edge 0, 1, and 2, where ~0 (= -1) indicates no adjacent triangle
    // indexes are relative to the iqmheader.ofs_triangles array and span all meshes, where 0 is the first triangle, 1 is the second, 2 is the third, etc.
    uint triangle[3];
};

struct iqmjoint
{
    uint name;
    int parent; // parent < 0 means this is a root bone
    float translate[3], rotate[4], scale[3];
    // translate is translation <Tx, Ty, Tz>, and rotate is quaternion rotation <Qx, Qy, Qz, Qw>
    // rotation is in relative/parent local space
    // scale is pre-scaling <Sx, Sy, Sz>
    // output = (input*scale)*rotation + translation
};

struct iqmpose
{
    int parent; // parent < 0 means this is a root bone
    uint channelmask; // mask of which 10 channels are present for this joint pose
    float channeloffset[10], channelscale[10];
    // channels 0..2 are translation <Tx, Ty, Tz> and channels 3..6 are quaternion rotation <Qx, Qy, Qz, Qw>
    // rotation is in relative/parent local space
    // channels 7..9 are scale <Sx, Sy, Sz>
    // output = (input*scale)*rotation + translation
};

struct iqmanim
{
    uint name;
    uint first_frame, num_frames;
    float framerate;
    uint flags;
};

enum // iqmanim flags
{
    IQM_LOOP = 1<<0
};

struct iqmbounds
{
    float bbmins[3], bbmaxs[3]; // the minimum and maximum coordinates of the bounding box for this animation frame
    float xyradius, radius; // the circular radius in the X-Y plane, as well as the spherical radius
};

struct iqmextension
{
    uint name;
    uint num_data, ofs_data;
    uint ofs_extensions; // pointer to next extension
};

// vertex data is not really interleaved, but this just gives examples of standard types of the data arrays
struct iqmvertex
{
    float position[3], texcoord[2], normal[3], tangent[4];
    uchar blendindices[4], blendweights[4], color[4];
};

]])

return ffi.C
