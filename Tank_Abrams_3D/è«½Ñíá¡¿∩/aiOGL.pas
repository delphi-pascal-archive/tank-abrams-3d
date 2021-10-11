
// не все файлы 3ds читаются корректно.  ike2009@mail.ru
// 
//                                                               Александр
unit aiOGL;

interface

uses
  OpenGL, Windows, Controls, SysUtils, Classes, Graphics, Dialogs, Messages,
    extctrls, Forms, jpeg;

//{$L-}
//{$D-}

type
  TTexFile = (tfOK, tfNoFile, tfNotFound, tfExtNotSupported, tfLoadError);

 { TBlendSourceFactor = set of(GL_ZERO, GL_ONE, GL_DST_COLOR, GL_ONE_MINUS_DST_COLOR,
    GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA, GL_DST_ALPHA, GL_ONE_MINUS_DST_ALPHA, GL_SRC_ALPHA_SATURATE);
  TBlendDestFactor = set of(GL_ZERO, GL_ONE, GL_SRC_COLOR, GL_ONE_MINUS_SRC_COLOR,
   GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA, GL_DST_ALPHA, GL_ONE_MINUS_DST_ALPHA);}

const

{$INCLUDE const.txt}

type
  TJitter = record
    Enabled: boolean;            // будет ли сцена сглаживаться
    Value: byte;
    PassCount: byte;            // кол-во проходов для сглаживания
  end;

  TGLObject = class;

  TOGL_InitError = (NoError, ChoosePixelFormatError, SetPixelFormatError,
                                         CreateContextError, MakeCurrentError);

  TVector = record
    X,Y,Z: single;
  end;

  TVertex = record
    U,V: single;            // текстурные координаты
    Normal: TVector;        // нормаль
    Vector: TVector;        // 3 координаты (X,Y,Z)
  end;

  TFace = record
    A,B,C: word;
  end;

  TMaterial = class;

  TFaceGroup = record
    Material: TMaterial;
    OriginFace: word;
    FaceCount: integer;
  end;

  TFaceGroups = array of TFaceGroup;

  TColorF = record
    R,G,B,A: single;          // RGBA floating point quadruple.
  end;

  TColorB = record
    R,G,B,A: byte;            // RGBA byte quadruple.
  end;

  TTranslation = record
    Frame: cardinal;
    Vector: TVector;
  end;

  TScaling = TTranslation;

  TRotation = record
    Frame: cardinal;
    Angle: single;
    Vector: TVector;
  end;

  TMatrix = array[0..3,0..3] of single;

  PMotion = ^TMotion;
  TMotion = record
    Name: string;
    Parent: integer;
    Pivot: TVector;                 // центр объекта
    TransKeyCount: cardinal;
    Translation: array of TTranslation;

    RotKeyCount: cardinal;      // кол-во ключей перемещения
    Rotation: array of TRotation;

    ScaleKeyCount: integer;         // кол-во ключей масштабирования
    Scaling: array of TScaling;
  end;

  TglScene = class;
  TTexture = class;

// ============================ TMaterials ==================================

  TMaterials = class
  private
    FMatCount: integer;
    FMaterials: array of TMaterial;
    FTexCount: integer;
    FTextures: array of TTexture;
//    function GetMaterial(MatName: string): TMaterial;
    function GetMaterialI(Index: integer): TMaterial;
    function MaterialIndexOf(Material: TMaterial): integer;
    function GetTexture(TexFileName: string): TTexture;
    function GetTextureI(Index: integer): TTexture;
    function TextureIndexOf(Texture: TTexture): integer;
    procedure SaveToFile(f: TFileStream);
    procedure ReadFromFile(f: TFileStream; FilePath: string);
  public
    destructor Destroy; override;
    property MatCount: integer read FMatCount;
    property Materials[Index: integer]: TMaterial read GetMaterialI; default;
    property TexCount: integer read FTexCount;
    property Textures[Index: integer]: TTexture read GetTextureI;
    function NewMaterial: TMaterial;
    function NewTexture: TTexture;
    procedure DeleteMaterialI(Index: integer);
    procedure DeleteTexture(Texture: TTexture);
    function GetMaterial(MatName: string): TMaterial;
  end;

// ======================== TMaterial ========================================

  TMaterial = class(TObject)
  private
    FShininess: single;
    procedure Apply;
    procedure SetShininess(AShininess: single);
  public
    Name: string;
    Ambient:  TColor;
    Diffuse:  TColor;
    Specular: TColor;
    Emission: TColor;
    Transparent: byte;
    DisableDepthTest: boolean;
    BlendSourceFactor, BlendDestFactor: cardinal;
    Texture: TTexture;
    property Shininess: single read FShininess write SetShininess;
    constructor Create;
  end;

// ================================ TTexture ================================

  TTexture = class(TObject)
  private
    FGLListNumber: cardinal;
    FTexFile: TTexFile;
    FFileSize: TPoint;
    FTextureSize: TPoint;
    File3dPath: string;     // путь к файлу 3ds сцены
    procedure Apply;
  public
    FileName: string;              // имя файла текстуры
    FoundFileName: string;
    MinFilter: integer;
    MagFilter: integer;
    WrapS: integer;
    WrapT: integer;
    EnvMode: integer;
    Transparent: byte;
    Use: boolean;
    constructor Create;
    destructor Destroy; override;
    property GLListNumber: cardinal read FGLListNumber;
    property TexFile: TTexFile read FTexFile;
    property FileSize: TPoint read FFileSize; // размер файла текстуры
    property TextureSize: TPoint read FTextureSize; // размер образа текстуры
    procedure Build;
  end;

// ================================= TglBackground ===========================

  TBackground = class(TObject)
  private
//    ListNumber: integer;
    procedure Paint;
    function GetClearColor: TColor;
    procedure SetClearColor(AClearColor: TColor);
    procedure Render;
  public
    ListNumber: integer;
    constructor Create;
    destructor Destroy; override;
    property ClearColor: TColor read GetClearColor write SetClearColor;
  end;

// ========================== TglObject =====================================

  TFaces = array of TFace;
  TVertices = array of TVertex;

  TglObject = class(TObject)
  private
    FGLListNumber: cardinal;
    FVertexCount: integer;
    FFaceCount: integer;
    FFaceGroupCount: integer;
    FBounding: boolean;
    MatrixBuilt: boolean;
    Smooth: array of cardinal;
    BuildGLList: boolean;
//    FacesRender: array of TFace;  // фейсы, измененные с учетом Smooth и добавлением при этом новых вершин
//    VCSave: integer;
    procedure Paint;
    procedure DrawBounding;
    procedure SetBounding(ABounding: boolean);
    procedure SetVertexCount(AVertexCount: integer);
    procedure SetFaceCount(AFaceCount: integer);
    procedure SetFaceGroupCount(AFaceGroupCount: integer);
    function GetMapped: boolean;
    function GetMin: TVector;
    function GetMax: TVector;
    procedure SaveToFile(f: TFileStream);
    procedure ReadFromFile(f: TFileStream);
  public
    Scene: TGLScene;
    Name: string;
    Visible: boolean;
    Frozen: boolean;
    PolygonMode: cardinal;
    Vertices: TVertices;
    Faces: TFaces;           // исходные фейсы, считанные из файла
    FaceGroups: TFaceGroups;
    Translate: TVector;
    Rotate: TVector;
    Scale: TVector;
    LocalTranslate: TVector; // X0,Y0,Z0: single;
//    Angle: TVector;
//    X,Y,Z: single;
    LocalRotate: TVector;
    CurTranslate: TVector;
    Matrix: TMatrix;
    GetShadow: boolean;             // будет ли принимать тень
    CastShadow: boolean;            // будет ли отбрасывать тень

    property GLListNumber: cardinal read FGLListNumber; // номер дисплейного списка OpenGL
    property VertexCount: integer read FVertexCount write SetVertexCount;


    property FaceCount: integer read FFaceCount write SetFaceCount;
    property FaceGroupCount: integer read FFaceGroupCount write SetFaceGroupCount;

    property Mapped: boolean read GetMapped;
    property Bounding: boolean read FBounding write SetBounding;
    property Min: TVector read GetMin;
    property Max: TVector read GetMax;

    constructor Create;
    destructor Destroy; override;
    procedure GetNormals;
    procedure Render;
    procedure Draw; virtual;
    procedure Draw_; virtual;
    procedure Assign(GLObject: TGLObject);
    procedure Translate_(Vector: TVector); overload;
    procedure Translate_(X,Y,Z: single);   overload;
    procedure Scale_(aVector: TVector); overload;
    procedure Scale_(X,Y,Z: single);   overload;
    procedure ToOrigin;

//    function Separate(FaceNumber: word): boolean;
  end;

// ============================= TLighting ====================================

  TLight = record
    Ambient: TColor;
    Diffuse: TColor;
    Specular: TColor;
    Position: TVector;
    Direction: TVector;
    AttConst,AttLinear,AttQuad: single;
    Exponent: single;
    CutOff: single;
    Infinity: boolean;
    Enabled: boolean;
  end;

  TLighting = class
  private
    class function GetLocalViewer: boolean;
    class procedure SetLocalViewer(ALocalViewer: boolean);
    class function GetTwoSide: boolean;
    class procedure SetTwoSide(ATwoSide: boolean);
    class function GetModelAmbient: TColor;
    class procedure SetModelAmbient(AModelAmbient: TColor);
    class function GetAmbient(Index: integer): TColor;
    class procedure SetAmbient(Index: integer; AAmbient: TColor);
    class function GetDiffuse(Index: integer): TColor;
    class procedure SetDiffuse(Index: integer; ADiffuse: TColor);
    class function GetSpecular(Index: integer): TColor;
    class procedure SetSpecular(Index: integer; ASpecular: TColor);
    class function GetPosition(Index: integer): TVector;
    class procedure SetPosition(Index: integer; APosition: TVector);
    class function GetDirection(Index: integer): TVector;
    class procedure SetDirection(Index: integer; ADirection: TVector);
    class function GetInfinity(Index: integer): boolean;
    class procedure SetInfinity(Index: integer; AInfinity: boolean);
    class function GetAttConst(Index: integer): single;
    class procedure SetAttConst(Index: integer; AAttConst: single);
    class function GetAttLinear(Index: integer): single;
    class procedure SetAttLinear(Index: integer; AAttLinear: single);
    class function GetAttQuad(Index: integer): single;
    class procedure SetAttQuad(Index: integer; AAttQuad: single);
    class function GetExponent(Index: integer): single;
    class procedure SetExponent(Index: integer; AExponent: single);
    class function GetCutOff(Index: integer): single;
    class procedure SetCutOff(Index: integer; ACutOff: single);
    class function GetEnabled(Index: integer): boolean;
    class procedure SetEnabled(Index: integer; AEnabled: boolean);
    class function GetLight(Index: integer): TLight;
    class procedure SetLight(Index: integer; Light: TLight);
  public
    property LocalViewer: boolean read GetLocalViewer write SetLocalViewer;
    property TwoSide: boolean read GetTwoSide write SetTwoSide;
    property ModelAmbient: TColor read GetModelAmbient write SetModelAmbient;

    property Ambient[Index: integer]: TColor read GetAmbient write SetAmbient;
    property Diffuse[Index: integer]: TColor read GetDiffuse write SetDiffuse;
    property Specular[Index: integer]: TColor read GetSpecular write SetSpecular;
    property Position[Index: integer]: TVector read GetPosition write SetPosition;
    property Direction[Index: integer]: TVector read GetDirection write SetDirection;
    property Infinity[Index: integer]: boolean read GetInfinity write SetInfinity;
    property AttConst[Index: integer]: single read GetAttConst write SetAttConst;
    property AttLinear[Index: integer]: single read GetAttLinear write SetAttLinear;
    property AttQuad[Index: integer]: single read GetAttQuad write SetAttQuad;
    property SpotExponent[Index: integer]: single read GetExponent write SetExponent;
    property SpotCutOff[Index: integer]: single read GetCutOff write SetCutOff;
    property Enabled[Index: integer]: boolean read GetEnabled write SetEnabled;
    property Lights[Index: integer]: TLight read GetLight write SetLight; default;
  end;

  TglTexts = class;

// =========================== TglScene =====================================

  TglScene = class(TObject)
  private
    FDC: hDC;
    GLRC: HGLRC;
    FErrorCode: TOGL_InitError;
    FScreen: TWinControl;
    FObjectCount: integer;
    FAutoAspect: boolean;
    MotionCount: integer;         //  кол-во объектов в Motions
    Motions: array of TMotion;    //  трансформации объектов
    WindowProcSave: TWndMethod;

    NormalVector: TVector;
    FileVersion: word;

    function InitOpenGL(DC: hDC; var GLRC: HGLRC): TOGL_InitError;
    procedure Read3DSFile(FName: string);
    procedure Read3DAFile(FName: string);
    procedure ClearAll;
    procedure SetAutoAspect(AAutoAspect: boolean);
    procedure SaveBMP(FName: string);
    procedure SaveJpeg(f: TFileStream);
    procedure FogSave(f: TFileStream);
    procedure FogRead(f: TFileStream);

    procedure BuildObjectsMatrix;
    procedure WndProcedure(var Message: TMessage);
    function GetMin: TVector;
    function GetMax: TVector;
    function GetRenderMode: cardinal;
    procedure SetRenderMode(ARenderMode: cardinal);
    property RenderMode: GLenum read GetRenderMode write SetRenderMode;
    procedure LightingSaveToFile(f: TFileStream);
    procedure LightingReadFromFile(f: TFileStream);
    procedure ReSize;
    function NewObject: TglObject;
    procedure Draw_;
  public
    Name: string;
    FileName: string;
    Objects: array of TglObject;
    Materials: TMaterials;
    BG: TBackground;
    FPS: single;
    Lighting: TLighting;
    EyePoint, RefPoint, UpVector: TVector;
    fovy, zNear, zFar, Aspect: single;
    Jitter: TJitter;
    Texts: TglTexts;
    constructor Create(GLScreen: TWinControl);
    destructor Destroy; override;

    property ErrorCode: TOGL_InitError read FErrorCode;
    property Screen: TWinControl read FScreen;
    property DC: hDC read FDC;

    property ObjectCount: integer read FObjectCount;

    property AutoAspect: boolean read FAutoAspect write SetAutoAspect;
    property Min: TVector read GetMin;
    property Max: TVector read GetMax;

    procedure LoadFromFile(FName: string); virtual;
    procedure SaveToFile;
    procedure DeleteObject(DelObject: TGLObject);
    procedure GetNormals;
    procedure RenderObject(glObject: TglObject); virtual;
    procedure Render;
    procedure Draw; virtual;
    procedure Paint;

    procedure Translate(X,Y,Z: single);
    procedure Rotate(X,Y,Z: single);
    procedure Scale(X,Y,Z: single);
    procedure LookAt;
    procedure Perspective;
    function  GetObjectFromScreenCoord(X,Y: integer): TGLObject;
    function glObject: TglObject; virtual;
    procedure AddObject(GLObject: TGLObject);
    function GetObject(ObjectName: string): TGLObject;
    function PixelsPerUnit: single;
    procedure LightsOff;
  end;

// ============================= TglText ====================================

  TglText = class
  private
    FontNumber: integer;
  public
    Text: string;
    Translate: TVector;
    Rotate: TVector;
    Scale: TVector;
    Frozen: boolean;
    UpFront: boolean;        // если True, текст всегда будет на переднем плане
    Material: TMaterial;     // материал, можно менять цвет, прозрачность или наложить текстуру
    constructor Create(aText: string);
  end;

// ============================= TglTexts ====================================

  TFontFormat = WGL_FONT_LINES..WGL_FONT_POLYGONS;

  TglTexts = class(TObject)
  private
    FFontCount: integer;              // кол-во используемых шрифтов
    OriginList: array of DWord;       // номера дисплейных списков первого символа шрифтов
    FTextCount: integer;
//    Texts: array of TglText;
    procedure Draw;
  public
    Texts: array of TglText;
    FontFormat: TFontFormat;
    Extrusion: single;
    constructor Create;
    property FontCount: integer read FFontCount;
    property TextCount: integer read FTextCount;
    function AddFont(aDC: hDC; Font: TFont): boolean;
    procedure DeleteFont(index: word);
    function AddText(aText: string): TglText;
  end;


  procedure SetCurScene(AglScene: TglScene);
  function CurScene: TglScene;

  function ColorF(cR,cG,cB,cA: single): TColorF;
  function ColorFToColorB(c: TColorF): TColorB;
  function ColorBToColorF(c: TColorB): TColorF;
  function ColorToColorF(C: TColor; aA: single): TColorF;
  function ColorToColorB(c: TColor; aA: byte): TColorB;
  function ColorBToTColor(c: TColorB): TColor;
  function ColorFToTColor(c: TColorF): TColor;
  function Vector(aX,aY,aZ: single): TVector;
  function Face(aA,aB,aC: integer): TFace;
  function PicturePosition(f: TFileStream): cardinal;
  function CreatePlane(Point1, Point2, Point3, Point4: TVector): TglObject;

const
  PutPictureInFile: boolean = True;
{$J-}
  Version: word = 110;
  NullVector: TVector = (X:0; Y:0; Z:0);
  IdentityMatrix: TMatrix = ((1,0,0,0),
                             (0,1,0,0),
                             (0,0,1,0),
                             (0,0,0,1));
{$J+}

var
  MaxLights: integer;
  MaxTextureSize: integer;
  SupportedExt: TStringList;
  ObjectFaceNumber: integer;
  
implementation

uses
  GraphicEx, ShellAPI;

type
  TJitterCount = set of byte;

var
  CurScene_: TglScene;
  DefaultMaterial: TMaterial;

const

  TexFileStr: array [0..3] of string[20] = ('No texture file', 'File not found',
                                             'Not Supported', 'Loading error');

var
  Saved8087CW: word;
  Power2: array of integer;
  DefaultLight: TLight;
  JitterC: TJitterCount;

procedure glInterleavedArrays(format: GLenum; stride: GLsizei; const pointer); stdcall; external OpenGL32;
procedure glDrawElements(mode: GLenum; count: GLsizei; atype: GLenum; const indices); stdcall; external OpenGL32;
procedure glGenTextures(n: GLsizei; textures: PGLuint); stdcall; external OpenGL32;
procedure glBindTexture(target: GLEnum; texture: GLuint); stdcall; external OpenGL32;
procedure glDeleteTextures(n: GLsizei; textures: PGLuint); stdcall; external OpenGL32;

type

  TVectorW = record
    Vector: TVector;
    W: single;
  end;

  Txy3 = array[0..2] of record
                       x,y,z: single;
                     end;
  Pxy3 = ^Txy3;

const
  GL_T2F_N3F_V3F = $2A2B;
//  GL_BGR_EXT = $80E0;
  GL_BGRA_EXT = $80E1;


function PicturePosition(f: TFileStream): cardinal;
var
  SavePos: cardinal;
begin
  SavePos:= f.Position;
  f.Position:= f.Size - SizeOf(cardinal);
  f.Read(Result, SizeOf(Result));
  f.Position:= SavePos; 
end;


procedure SetCurScene(AglScene: TglScene);
begin
  if AglScene is TglScene then
    begin
      wglMakeCurrent(AglScene.DC, AglScene.GLRC);
      CurScene_:= AglScene;
    end;
end;

function CurScene: TglScene;
begin
  Result:= CurScene_;
end;

{$H-}
procedure WriteString(FileSt: TFileStream; Str: string);
var
  c: char;
begin
  FileSt.WriteBuffer(Str[1], Length(Str));
  c:= #0; FileSt.Write(c, 1);
end;

function ReadString(f: TFileStream): string;
var
  Len: Integer;
  Buffer: array[Byte] of char;
begin
  Len:= 0;
  repeat
    f.Read(Buffer[Len], 1);
    Inc(Len);
  until Buffer[Len - 1] = #0;
  SetString(Result, Buffer, Len - 1); // not the null byte
end;
{$H+}

function PointInTriangles(xy: Pxy3; x,y: integer): boolean;
var
  i,j : Integer;
begin
  Result:= False;
  for i:= 0 to 2 do
  begin
    j:= i + 1;
    if i = 2 then
      j:= 0;
    if ((((xy[i].y <= y) and (y < xy[j].y)) or ((xy[j].y <= y) and (y < xy[i].y)))
      and (x < (xy[j].x-xy[i].x)*(y-xy[i].y)/(xy[j].y-xy[i].y)+xy[i].x))
    then Result:= not Result;
  end;
end;

function Vector(aX,aY,aZ: single): TVector;
begin
  with Result do
    begin
      X:= aX;
      Y:= aY;
      Z:= aZ;
  end;
end;

function Face(aA,aB,aC: integer): TFace;
begin
  with Result do
    begin
      A:= aA;
      B:= aB;
      C:= aC;
  end;
end;

function AddVectors(Vector1, Vector2: TVector): TVector;
begin
  with Result do
    begin
      X:= Vector1.x + Vector2.x;
      Y:= Vector1.y + Vector2.y;
      Z:= Vector1.z + Vector2.z;
    end;
end;

procedure Mirror(var v: TVector; mx,my,mz: boolean);
begin
  { Mirror v around any axis. }
  with v do
  begin
    if mx then x := -x;
    if my then y := -y;
    if mz then z := -z;
  end;
end;

procedure TranslateV(var v: TVector; t: TVector);
begin
  { Translate vector v over vector t. }
  with v do
  begin
    x := x + t.x;
    y := y + t.y;
    z := z + t.z;
  end;
end;

function CrossProduct(v1,v2: TVector): TVector;
begin
  // Return the cross product v1 x v2.
  Result := Vector(v1.y * v2.z - v2.y * v1.z, v2.x * v1.z - v1.x * v2.z,
                                                    v1.x * v2.y - v2.x * v1.y);
end;

function VectorLength(v: TVector): single;
begin
  { Calculate v's length (distance to the origin), using Pythagoras in 3D. }
  Result := sqrt(v.x*v.x + v.y*v.y + v.z*v.z);
end;

function Normalize(var v: TVector): single;
begin
  { Normalize a vector by dividing its components by its length. }
  Result := VectorLength(v);
  if Result <> 0 then
  begin
    with v do
    begin
      x := x / Result;
      y := y / Result;
      z := z / Result;
    end;
  end;
end;

function GetNormal(v1, v2, v3: TVector): TVector;
begin
  // Return the normal vector to the plane defined by v1, v2 and v3.
  Mirror(v2, TRUE, TRUE, TRUE);
  TranslateV(v1, v2);
  TranslateV(v3, v2);
  Result:= CrossProduct(v1, v3);
 // Normalize(Result);
end;

function VectorDistance(v1, v2: TVector): single;
begin
  { Calculate the distance between two points. }
  Mirror(v1, TRUE, TRUE, TRUE);
  TranslateV(v2, v1);
  Result := VectorLength(v2);
end;

function ColorF(cR,cG,cB,cA: single): TColorF;
begin
  { Create a TCGColor. Clamp values to [0..1]. }
  with Result do
  begin
    R := cR; if R > 1 then R := 1 else if R < 0 then R := 0;
    G := cG; if G > 1 then G := 1 else if G < 0 then G := 0;
    B := cB; if B > 1 then B := 1 else if B < 0 then B := 0;
    A := cA; if A > 1 then A := 1 else if A < 0 then A := 0;
  end;
end;

function ColorFToColorB(c: TColorF): TColorB;
begin
  { Convert float quad to byte quad. }
  with Result do
  begin
    R := Round(c.R * 255);
    B := Round(c.B * 255);
    G := Round(c.G * 255);
    A := Round(c.A * 255);
  end;
end;

function ColorBToColorF(c: TColorB): TColorF;
begin
  { Convert byte quad to float quad. }
  with Result do
  begin
    R := c.R / 255;
    B := c.B / 255;
    G := c.G / 255;
    A := c.A / 255;
  end;
end;

function ColorToColorF(c: TColor; aA: single): TColorF;
begin
  { Convert TColor to TColor.}
  with Result do
  begin
//    R := (c mod $100) / 255;
    R:= (c and $000000FF) / 255;
//    G := ((c div $100) mod $100) / 255;
    G:= (c and $0000FF00 shr 8) / 255;
//    B := (c div $10000) / 255;
    B:= (c and $00FF0000 shr 16) / 255;
    A:= aA;
  end;

end;

function ColorToColorB(c: TColor; aA: byte): TColorB;
begin
  { Convert TColor to TCGColor. TColor doesn't have alpha, so pass it separately. }
  with Result do
  begin
//    R := (c mod $100);
    R:= c and $000000FF;
//    G := ((c div $100) mod $100);
    G:= c and $0000FF00 shr 8;
//    B := (c div $10000);
    B:= c and $00FF0000 shr 16;
    A:= aA;
  end;
end;

function ColorFToTColor(c: TColorF): TColor;
var
  cc: array[0..3] of byte absolute Result;
begin
  cc[0]:= Round(c.r * 255); cc[1]:= Round(c.g * 255); cc[2]:= Round(c.b * 255);
  cc[3]:= 0;
end;

function ColorBToTColor(c: TColorB): TColor;
begin
  Result:= ColorFToTColor(ColorBToColorF(c));
end;

function CreatePlane(Point1, Point2, Point3, Point4: TVector): TglObject;
begin
  Result:= TglObject.Create;
  CurScene.AddObject(Result);
  with Result do
    begin
      VertexCount:= 4;
      Vertices[0].Vector:= Point1; Vertices[1].Vector:= Point2;
      Vertices[2].Vector:= Point3; Vertices[3].Vector:= Point4;

      FaceCount:= 2;
      Faces[0]:= Face(0, 1, 3); Faces[1]:= Face(1, 2, 3);

      FaceGroupCount:= 1;
      FaceGroups[0].Material:= Nil; FaceGroups[0].OriginFace:= 0; FaceGroups[0].FaceCount:= 2;
    end;

end;

// =========================== TMaterials ===================================

destructor TMaterials.Destroy;
var
  i: integer;
begin
  for i:= 0 to MatCount - 1 do
    FMaterials[i].Free;
  FMatCount:= 0;
  SetLength(FMaterials, 0);
  for i:= 0 to TexCount - 1 do
    FTextures[i].Free;
  FTexCount:= 0;
  SetLength(FTextures, 0);
  inherited Destroy;
end;

function TMaterials.GetMaterialI(Index: integer): TMaterial;
begin
  if (Index >= 0) and (Index < FMatCount) then
    Result:= FMaterials[Index] else
    Result:= DefaultMaterial;
end;

function TMaterials.GetTextureI(Index: integer): TTexture;
begin
  if (Index >= 0) and (Index < FTexCount) then
    Result:= FTextures[Index] else
    Result:= Nil;
end;

function TMaterials.TextureIndexOf(Texture: TTexture): integer;
var
  i: integer;
begin
  Result:= -1;
  for i:= 0 to TexCount - 1 do
    if Textures[i] = Texture then
      begin
        Result:= i;
        Exit;
      end;
end;

function TMaterials.NewMaterial: TMaterial;
begin
  Inc(FMatCount);
  SetLength(FMaterials, FMatCount);
  FMaterials[FMatCount-1]:= TMaterial.Create;
  Result:= FMaterials[FMatCount-1];
end;

function TMaterials.MaterialIndexOf(Material: TMaterial): integer;
var
  i: integer;
begin
  Result:= -1;
  for i:= 0 to MatCount - 1 do
    if Materials[i] = Material then
      begin
        Result:= i;
        Exit;
      end;
end;

function TMaterials.NewTexture: TTexture;
begin
  Inc(FTexCount);
  SetLength(FTextures, FTexCount);
  FTextures[FTexCount-1]:= TTexture.Create;
  Result:= FTextures[FTexCount-1];
end;

function TMaterials.GetMaterial(MatName: string): TMaterial;
var
  i: integer;
begin
  Result:= Nil;
  for i:= 0 to FMatCount - 1 do
    if AnsiUpperCase(Materials[i].Name) = AnsiUpperCase(MatName) then
      begin
        Result:= Materials[i];
        Exit;
      end;
end;

function TMaterials.GetTexture(TexFileName: string): TTexture;
var
  i: integer;
begin
  Result:= Nil;
  for i:= 0 to FTexCount - 1 do
    if AnsiUpperCase(Textures[i].FileName) = AnsiUpperCase(TexFileName) then
      begin
        Result:= Textures[i];
        Exit;
      end;
end;

procedure TMaterials.DeleteMaterialI(Index: integer);
var
  i,j: integer;
begin
  if (Index >= 0) and (Index < FMatCount) then
    begin
      with CurScene do
        for i:= 0 to ObjectCount - 1 do
          with Objects[i] do
            for j:= 0 to FaceGroupCount - 1 do
              with FaceGroups[j] do
                if Material = Materials[Index] then
                  Material:= Nil;

      FMaterials[Index].Free;
      Move(FMaterials[Index+1], FMaterials[Index], SizeOf(TMaterial) * (MatCount - Index - 1));
      Dec(FMatCount);
      SetLength(FMaterials, MatCount);
    end;
end;

procedure TMaterials.DeleteTexture(Texture: TTexture);
var
  i: integer;
begin
 if (Texture <> nil) and (Texture is TTexture) then
    begin
      for i:= 0 to MatCount - 1 do
// если удаляется используемая текстура, то ставим nil
        if Materials[i].Texture = Texture then
          Materials[i].Texture:= Nil;
      i:= TextureIndexOf(Texture);
      Textures[i].Free;
      Move(FTextures[i+1], FTextures[i], SizeOf(TTexture) * (TexCount - i - 1));
      Dec(FTexCount);
      SetLength(FTextures, TexCount);
    end;
end;

procedure TMaterials.SaveToFile(f: TFileStream);
var
  i: integer;
  ind: smallint;
  ColorB: TColorB;
  TexPar: byte;
begin
// сохранить текстуры
  f.Write(TexCount, SizeOf(TexCount));  // кол-во текстур
  for i:= 0 to TexCount - 1 do
    with Textures[i] do
      begin
        WriteString(f, FileName);  // Texture file name
        TexPar:= 0;
        if MinFilter = GL_NEAREST then
          TexPar:= TexPar or 1;
        if MagFilter = GL_NEAREST then
          TexPar:= TexPar or 2;
        if WrapS = GL_CLAMP then
          TexPar:= TexPar or 4;
        if WrapT = GL_CLAMP then
          TexPar:= TexPar or 8;
        if EnvMode = GL_DECAL then
          TexPar:= TexPar or 16;
        if EnvMode = GL_BLEND then
          TexPar:= TexPar or 32;
        f.Write(TexPar, SizeOf(TexPar));           // параметры текстуры
        f.Write(Transparent, SizeOf(Transparent)); // прозрачность
//        f.Write(w, SizeOf(w));                     // резерв
      end;
// сохранить материалы
  f.Write(MatCount, SizeOf(MatCount));  // кол-во материалов
  for i:= 0 to MatCount - 1 do
    with Materials[i] do
      begin
        WriteString(f, Name);     // имя материала
        ColorB:= ColorToColorB(Ambient, 255);
        f.Write(ColorB, 3);                 // Ambient
        ColorB:= ColorToColorB(Diffuse, 255);
        f.Write(ColorB, 3);                 // Diffuse
        ColorB:= ColorToColorB(Specular, 255);
        f.Write(ColorB, 3);                 // Specular
        ColorB:= ColorToColorB(Emission, 255);
        f.Write(ColorB, 3);                 // Emission
        f.Write(FShininess, SizeOf(FShininess));            // FShininess
        f.Write(Transparent, SizeOf(Transparent));          // Transparent
// индекс текстуры материала из Textures
        ind:= TextureIndexOf(Texture);
        f.Write(ind, SizeOf(ind));
 //       f.Write(w, SizeOf(w));                              // reserve
      end;
end;

procedure TMaterials.ReadFromFile(f: TFileStream; FilePath: string);
var
  i: integer;
  TexPar: byte;
  ColorB: TColorB;
  ind: smallint;
begin
// прочитать текстуры
  f.Read(i, SizeOf(i));  // кол-во текстур
  for i:= 1 to i do
    with NewTexture do
      begin
        File3dPath:= FilePath;
        FileName:= ReadString(f);  // Texture file name
        f.Read(TexPar, 1);
        if (TexPar and 1) <> 0 then
          MinFilter:= GL_NEAREST else MinFilter:= GL_LINEAR;
        if (TexPar and 2) <> 0 then
          MagFilter:= GL_NEAREST else MagFilter:= GL_LINEAR;
        if (TexPar and 4) <> 0 then
          WrapS:= GL_CLAMP else WrapS:= GL_REPEAT;
        if (TexPar and 8) <> 0 then
          WrapT:= GL_CLAMP else WrapT:= GL_REPEAT;
        if (TexPar and 16) <> 0 then
          EnvMode:= GL_DECAL else EnvMode:= GL_MODULATE;
        if (TexPar and 32) <> 0 then
          EnvMode:= GL_BLEND;
        f.Read(Transparent, SizeOf(Transparent));
//        f.Seek(2, soFromCurrent); // пропустить резервное поле
      end;
// прочитать материалы
  f.Read(i, SizeOf(i));  // кол-во материалов
  for i:= 1 to i do
    with NewMaterial do
      begin
        Name:= ReadString(f);     // имя материала
        f.Read(ColorB, 3);                  // Ambient
        Ambient:= ColorBToTColor(ColorB);
        f.Read(ColorB, 3);                  // Diffuse
        Diffuse:= ColorBToTColor(ColorB);
        f.Read(ColorB, 3);                  // Specular
        Specular:= ColorBToTColor(ColorB);
        f.Read(ColorB, 3);                  // Emission
        Emission:= ColorBToTColor(ColorB);
        f.Read(FShininess, SizeOf(FShininess));            // FShininess
        f.Read(Transparent, SizeOf(Transparent));          // Transparent
// индекс текстуры материала из Textures
        f.Read(ind, SizeOf(ind));
        if (ind < 0) or (ind >= TexCount) then
          Texture:= Nil else
          Texture:= Textures[ind];
  //      f.Seek(2, soFromCurrent);                          // reserve
      end;
end;

// ================== TMaterial ================================================

constructor TMaterial.Create;
begin
  inherited Create;
  Name:= '';
  Ambient:= RGB(51, 51, 51);
  Diffuse:= RGB(204, 204, 204);
  Specular:= RGB(0, 0, 0);
  Emission:= RGB(0, 0, 0);
  Shininess:= 0;
  Transparent:= 0;
  DisableDepthTest:= True;
  BlendSourceFactor:= GL_SRC_ALPHA;
  BlendDestFactor:= GL_ONE_MINUS_SRC_ALPHA;
  Texture:= Nil;
end;

procedure TMaterial.SetShininess(AShininess: single);
begin
  if FShininess = AShininess then
    Exit;
  if (AShininess < 0) or (AShininess > 128) then
    FShininess:= 0 else
    FShininess:= AShininess;
end;

procedure TMaterial.Apply;
var
  CF: TColorF;
begin
  glEnable(GL_BLEND);
  glBlendFunc(BlendSourceFactor, BlendDestFactor);
  if Transparent <> 0 then
    begin
      glEnable(GL_BLEND);

      if DisableDepthTest then
        glDepthMask(GL_FALSE) else
        glDepthMask(GL_TRUE);
      glBlendFunc(BlendSourceFactor, BlendDestFactor);
    end else
      begin
        glDisable(GL_BLEND);
        glDepthMask(GL_TRUE);
  //      glEnable(GL_DEPTH_TEST);
      end;
  CF:= ColorToColorF(Ambient, (255 - Transparent) /255);
  glMaterialfv(GL_FRONT_AND_BACK, GL_AMBIENT, @CF);
  CF:= ColorToColorF(Diffuse, (255 - Transparent) /255);
  glMaterialfv(GL_FRONT_AND_BACK, GL_DIFFUSE, @CF);
  CF:= ColorToColorF(Specular, (255 - Transparent) /255);
  glMaterialfv(GL_FRONT_AND_BACK, GL_SPECULAR, @CF);
  CF:= ColorToColorF(Emission, (255 - Transparent) /255);
  glMaterialfv(GL_FRONT_AND_BACK, GL_EMISSION, @CF);
  glMaterialfv(GL_FRONT_AND_BACK, GL_SHININESS, @Shininess);
end;

// ==================== TTexture ==============================================

constructor TTexture.Create;
begin
  inherited Create;
  FileName:= '';
  Transparent:= 0;
  MinFilter:= GL_NEAREST;
  MagFilter:= GL_LINEAR;
  WrapS:= GL_REPEAT;
  WrapT:= GL_REPEAT;
  EnvMode:= GL_MODULATE;
  Use:= True;
end;

destructor TTexture.Destroy;
begin
  glDeleteTextures(1, @GLListNumber);
  inherited Destroy;
end;

procedure TTexture.Build;
var
  i,j,k: integer;
  FileImage, TextureImage: array of byte;
  Line: PByteArray;
  JpegImage: TJpegImage;
  Ext: string;
  Picture: TPicture;
  ExePath: string;

function SearchFile: boolean;
begin
  Result:= True;
  if FileExists(FileName) then  // если имя файла указано явно или в системной папке
    begin
      FoundFileName:= FileName;
      Exit;
    end;
  if FileExists(File3dPath + FileName) then  // ищем в папке с 3ds файлом
    begin
      FoundFileName:= File3dPath + FileName;
      Exit;
    end;
  if FileExists(File3dPath + 'Textures\' + FileName) then
    begin
      FoundFileName:= File3dPath + 'Textures\' + FileName;
      Exit;
    end;

  ExePath:= ExtractFilePath(Application.ExeName);
// в папке запуска  
  if FileExists(ExePath + FileName) then
    begin
      FoundFileName:= ExePath + FileName;
      Exit;
    end;
// в папке запуска + 'Textures\
  if FileExists(ExePath + 'Textures\' + FileName) then
    begin
      FoundFileName:= ExePath + 'Textures\' + FileName;
      Exit;
    end;
  Result:= False;
end;

function RoundDownToPowerOf2(Value: Integer): Integer;
var
  i: integer;
begin
  for i:= 0 to High(Power2) do
    if Power2[i] > Value then
      begin
        Result:= Power2[i-1];
        Exit;
      end;
 { Result:= Round(Power(2, Trunc(log2(Value))));
  if Result > MaxTextureSize then
    Result:= MaxTextureSize; }
end;

begin
  Screen.Cursor:= crHourGlass;
  try
  glDeleteTextures(1, @GLListNumber);
  FGLListNumber:= 0;
  if FileName = '' then
    begin
      FTexFile:= tfNoFile;
      Exit;
    end;
  if not SearchFile then
    begin
      FTexFile:= tfNotFound;
      Exit;
    end;

  Ext:= UpperCase(ExtractFileExt(FileName));
  if SupportedExt.IndexOf(Ext) = -1 then
    begin
      FTexFile:= tfExtNotSupported;
      Exit;
    end;

  Picture:= TPicture.Create;
  try
  if (Ext = '.JPEG') or ({not NVLibLoaded and} (Ext = '.JPG'))  then
    begin
      JpegImage:= TJpegImage.Create;
      JpegImage.LoadFromFile(FoundFileName);
      Picture.Bitmap.Assign(JpegImage);
      JpegImage.Free;
    end  else
      Picture.LoadFromFile(FoundFileName);
  except
    FTexFile:= tfLoadError;
    Exit;
  end;


//  Picture.Bitmap.HandleType:= bmDIB;
  Picture.Bitmap.PixelFormat:= pf24bit;

  SetLength(FileImage, Picture.BitMap.Width * Picture.BitMap.Height * 4);
  k:= 0;
  with Picture.BitMap do
    for i:= Height - 1 downto 0 do
      begin
        Line:= ScanLine[i];
        for j:= 0 to Width - 1 do
          begin
            Move(Line^[j*3], FileImage[k], 3);
            FileImage[k+3]:= 255 - Self.Transparent;
            Inc(k, 4);
          end;
      end;
  FFileSize:= Point(Picture.BitMap.Width, Picture.BitMap.Height);
  Picture.Free;
 // if (FileSize.X < 2 ) or (FileSize.Y < 2) then
 //   begin
 //     i:= i;
 //     SetLength(FileImage, 0);
 //     Exit;
 //   end;
//  glGetIntegerv(GL_MAX_TEXTURE_SIZE, @MaxTextureSize);
// Определить новые размеры текстуры, кратные степени 2
  FTextureSize:= Point(RoundDownToPowerOf2(FileSize.X), RoundDownToPowerOf2(FileSize.Y));
// Выделить память под масштабированную текстуру
  SetLength(TextureImage, TextureSize.X * TextureSize.Y * 4);
// Масштабируем текстуру
  gluScaleImage(GL_RGBA, FileSize.X, FileSize.Y, GL_UNSIGNED_BYTE, FileImage,
                 TextureSize.X, TextureSize.Y, GL_UNSIGNED_BYTE, TextureImage);
  SetLength(FileImage, 0);
  glGenTextures(1, @GLListNumber);
  glBindTexture(GL_TEXTURE_2D, GLListNumber);
  glTexImage2D(GL_TEXTURE_2D, 0, 4, TextureSize.X, TextureSize.Y, 0, GL_BGRA_EXT, GL_UNSIGNED_BYTE, TextureImage);
//  gluBuild2DMipmaps(GL_TEXTURE_2D, 4, TextureSize.X, TextureSize.Y, GL_BGRA_EXT, GL_UNSIGNED_BYTE, {Texture}FileImage);
  SetLength(TextureImage, 0);
  FTexFile:= tfOK;
//  TexFileHandle:= FindFirstChangeNotification(pChar(ExtractFilePath(FileName)),
  //                                      False, FILE_NOTIFY_CHANGE_LAST_WRITE);
  finally
    Screen.Cursor:= crDefault;
  end;
end;

procedure TTexture.Apply;
begin
  if (GLListNumber = 0) or not Use then
    begin
      glDisable(GL_TEXTURE_2D);
      Exit;
    end;
  glEnable(GL_TEXTURE_2D);
  if Transparent <> 0 then
    begin
      glEnable(GL_BLEND);
      glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    end else
    glDisable(GL_BLEND);
  glBindTexture(GL_TEXTURE_2D, GLListNumber);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, MinFilter);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, MagFilter);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, WrapS);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, WrapT);
  glTexEnvi(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, EnvMode);
end;

// =========================== TglBackground ==================================

constructor TBackground.Create;
begin
  inherited Create;
  ListNumber:= 0;
//  Texture:= TTexture.Create;
  ClearColor:= RGB(128, 128, 191);
end;

destructor TBackground.Destroy;
begin
//  Texture.Free;
  inherited Destroy;
end;

function TBackground.GetClearColor: TColor;
var
  CF: TColorF;
begin
  glGetFloatv(GL_COLOR_CLEAR_VALUE, @CF);
  Result:= ColorFToTColor(CF);
end;

procedure TBackground.SetClearColor(AClearColor: TColor);
var
  CF: TColorF;
begin
  if ClearColor <> AClearColor then
    begin
      CF:= ColorToColorF(AClearColor, 1);
      glClearColor(CF.R, CF.G, CF.B, CF.A);
      Render;
    end;
end;

procedure TBackground.Render;
begin
  if ListNumber <> 0 then
    begin
      glDeleteLists(ListNumber, 1);
      ListNumber:= 0;
    end;
  ListNumber:= glGenLists(1);
  glNewList(ListNumber, GL_COMPILE);
  Paint;
  glEndList;
end;

procedure TBackground.Paint;
begin
  glClear(GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT);
//  glDrawBuffer(GL_FRONT);
{  BGBitMap:= TBitMap.Create;
  BGBitMap.omFile('CAMUFLAG.BMP');
  StretchBlt(DC, 0, 0, Screen.ClientWidth, Screen.ClientHeight,
   BGBitMap.Canvas.Handle, 0, 0,
    BGBitMap.Width, BGBitMap.Height, SRCCOPY);

  BGBitMap.Free; }

//  if Texture.TexImage = nil then
//    Exit;

(*  Texture.Apply;
  if Texture.TexImage = nil then
    Exit;
  glDisable(GL_LIGHTING);

  with Scene do
    begin
      r:= (zFar-1) * tan(fovy*pi/360);
      glBegin(GL_QUADS);

      glTexCoord2i(0, 0);
      glVertex3f(-r*Aspect+EyeX, -r+EyeY ,-zFar+EyeZ+1);

      glTexCoord2i(1, 0);
      glVertex3f(r*Aspect+EyeX, -r+EyeY, -zFar+EyeZ+1);

      glTexCoord2i(1, 1);
      glVertex3f(r*Aspect+EyeX, r+EyeY, -zFar+EyeZ+1);

      glTexCoord2i(0, 1);
      glVertex3f(-r*Aspect+EyeX, r+EyeY, -zFar+EyeZ+1);

      glEnd;
    end;
  glEnable(GL_LIGHTING); *)
end;

// =========================== TGLObject ======================================

constructor TglObject.Create;
begin
  inherited Create;
  FVertexCount:= 0;
  FFaceCount:= 0;
  FFaceGroupCount:= 0;
  Visible:= True;
  FBounding:= False;
  Frozen:= False;
  Matrix:= IdentityMatrix;
  MatrixBuilt:= False;
  FGLListNumber:= 0;
  Translate:= NullVector;
  Rotate:= NullVector;
  Scale:= Vector(1, 1, 1);
  PolygonMode:= GL_FILL;
  BuildGLList:= True;
  GetShadow:= False;
  CastShadow:= True;
end;

destructor TGLObject.Destroy;
begin
  if glIsList(glListNumber) then
    glDeleteLists(GLListNumber, 1);
  FaceGroupCount:= 0;
  FaceCount:= 0;
  VertexCount:= 0;
  SetLength(Smooth, 0);
  inherited Destroy;
end;

procedure TGLObject.Assign(GLObject: TGLObject);
var
  i: integer;
begin
  if (not (GLObject is TGLObject)) or (not Assigned(GLObject)) then
    Exit;
//  Scene:= GLObject.Scene;
  Name:= GLObject.Name;
  Visible:= GLObject.Visible; FBounding:= GLObject.FBounding;
  Frozen:= GLObject.Frozen; Matrix:= GLObject.Matrix; MatrixBuilt:= GLObject.MatrixBuilt;
  VertexCount:= GLObject.VertexCount;

  Move(GLObject.Vertices[0], Vertices[0], Sizeof(TVertex)* VertexCount);
  FaceCount:= GLObject.FaceCount;
  Move(GLObject.Faces[0], Faces[0], Sizeof(TFace)* FaceCount);
  FaceGroupCount:= GLObject.FFaceGroupCount;
  Move(GLObject.FaceGroups[0], FaceGroups[0], Sizeof(TFaceGroup)* FaceGroupCount);
//  если объекты из разных сцен, материал копируемого объекта может впоследствии не существовать
//                                                      сцена будет уничтожена
  if GLObject.Scene <> Scene then
    for i:= 0 to FaceGroupCount do
      FaceGroups[0].Material:= Nil;

  Translate:= GLObject.Translate; Rotate:= GLObject.Rotate; Scale:= GLObject.Scale;
  PolygonMode:= glObject.PolygonMode;
  GetShadow:= glObject.GetShadow; CastShadow:= glObject.CastShadow;
  LocalTranslate:= glObject.LocalTranslate; LocalRotate:= glObject.LocalRotate;
  CurTranslate:= glObject.CurTranslate; BuildGLList:= glObject.BuildGLList;
end;

procedure TglObject.Translate_(Vector: TVector);
var
  i: integer;
begin
  for i:= 0 to VertexCount - 1 do
    Vertices[i].Vector:= AddVectors(Vertices[i].Vector, Vector);
end;

procedure TglObject.Translate_(X,Y,Z: single);
var
  i: integer;
begin
  for i:= 0 to VertexCount - 1 do
    begin
      Vertices[i].Vector.X:= Vertices[i].Vector.X + X;
      Vertices[i].Vector.Y:= Vertices[i].Vector.Y + Y;
      Vertices[i].Vector.Z:= Vertices[i].Vector.Z + Z;
    end;
end;

procedure TGLObject.Scale_(aVector: TVector);
var
  i: integer;
begin
  for i:= 0 to VertexCount - 1 do
    Vertices[i].Vector:= Vector(Vertices[i].Vector.X * aVector.X,
                                Vertices[i].Vector.Y * aVector.Y,
                                Vertices[i].Vector.Z * aVector.Z);
end;

procedure TGLObject.Scale_(X,Y,Z: single);
var
  i: integer;
begin
  for i:= 0 to VertexCount - 1 do
    begin
      Vertices[i].Vector.X:= Vertices[i].Vector.X * X;
      Vertices[i].Vector.Y:= Vertices[i].Vector.Y * Y;
      Vertices[i].Vector.Z:= Vertices[i].Vector.Z * Z;
    end;
end;

procedure TGLObject.ToOrigin;
var
  Mx,Mn: TVector;
begin
  Mx:= Max; Mn:= Min;
  Translate_(-(Mx.X + Mn.X)/2, -(Mx.Y + Mn.Y)/2, -(Mx.Z + Mn.Z)/2);
end;

procedure TglObject.DrawBounding;
var
  Mx, Mn: TVector;
begin
//  glNormal3f(0, 0, 1);
  Mx:= Max; Mn:= Min;
  glBegin(GL_LINE_LOOP);
    glVertex3f(Mn.X, Mn.Y, Mn.Z);
    glVertex3f(Mn.X, Mn.Y, Mx.Z);
    glVertex3f(Mx.X, Mn.Y, Mx.Z);
    glVertex3f(Mx.X, Mn.Y, Mn.Z);
  glEnd;
  glBegin(GL_LINE_LOOP);
    glVertex3f(Mn.X, Mx.Y, Mn.Z);
    glVertex3f(Mn.X, Mx.Y, Mx.Z);
    glVertex3f(Mx.X, Mx.Y, Mx.Z);
    glVertex3f(Mx.X, Mx.Y, Mn.Z);
  glEnd;

  glBegin(GL_LINES);
    glVertex3f(Mn.X, Mn.Y, Mn.Z);
    glVertex3f(Mn.X, Mx.Y, Mn.Z);
    glVertex3f(Mx.X, Mn.Y, Mn.Z);
    glVertex3f(Mx.X, Mx.Y, Mn.Z);
    glVertex3f(Mn.X, Mn.Y, Mx.Z);
    glVertex3f(Mn.X, Mx.Y, Mx.Z);
    glVertex3f(Mx.X, Mn.Y, Mx.Z);
    glVertex3f(Mx.X, Mx.Y, Mx.Z);
  glEnd;
end;

procedure TGLObject.GetNormals;
type
  TSI = record
    Sm: byte;
    Ind: word;
  end;
  TVS = record
    CSI: byte;
    SI: array of TSI;
  end;
var
  i: integer;
//  VSmooth: array of TVS;       // массив Smooth-ов для вершин
  VAddedCount: word;
  normal: TVector;
//  SmoothGroup: byte;

{procedure SendVIndex(var VIndex: word);
var
  i: integer;
begin
  with VSmooth[VIndex] do
    begin
      if CSI = 0 then   // если зта вершина попала в первый раз
        begin
          Inc(CSI);
          SetLength(SI, CSI);
          SI[CSI-1].Sm:= SmoothGroup;
          SI[CSI-1].Ind:= VIndex;
        end else
        begin
          for i:= 0 to CSI - 1 do
            if SI[i].Sm = SmoothGroup then
              begin
                VIndex:= SI[i].Ind;  // вершина с этим SmoothGroup уже была
                Exit;
              end;
// здесь добавить новую вершину
          Inc(CSI);
          SetLength(SI, CSI);
          SI[CSI-1].Sm:= SmoothGroup;
          SI[CSI-1].Ind:= VAddedCount + VCSave;

          Inc(VAddedCount);
          if VAddedCount + VCSave > VertexCount then
            VertexCount:= VertexCount + 300;   // увеличить кол-во вершин сразу на 300
          Vertices[VCSave + VAddedCount - 1]:= Vertices[VIndex];
          Vindex:= VCSave + VAddedCount - 1;
          Vertices[VIndex].Normal:= NullVector;
        end;
    end;
end; }

begin
  Screen.Cursor:= crHourGlass;
  try
  for i:= 0 to VertexCount - 1 do
    Vertices[i].Normal:= NullVector;
//  VCSave:= VertexCount;
  VAddedCount:= 0;
//  SetLength(FacesRender, FaceCount);
//  Move(Faces[0], FacesRender[0], FaceCount * SizeOf(TFace));
//  SetLength(VSmooth, VertexCount);   // выделить память под массив Smooth вершин
  for i:= 0 to FaceCount - 1 do
    begin
      normal:= GetNormal(Vertices[Faces{Render}[i].A].Vector, Vertices[Faces{Render}[i].C].Vector,
                                                  Vertices[Faces{Render}[i].B].Vector);
{      if Assigned(Smooth) then
        begin
          SmoothGroup:= Smooth[i];
          SendVIndex(FacesRender[i].A);
          SendVIndex(FacesRender[i].B);
          SendVIndex(FacesRender[i].C);
        end; }
      Vertices[Faces{Render}[i].A].Normal:= AddVectors(Vertices[Faces{Render}[i].A].Normal, normal);
      Vertices[Faces{Render}[i].B].Normal:= AddVectors(Vertices[Faces{Render}[i].B].Normal, normal);
      Vertices[Faces{Render}[i].C].Normal:= AddVectors(Vertices[Faces{Render}[i].C].Normal, normal);
    end;
{  for i:= 0 to VCSave - 1 do
    SetLength(VSmooth[i].SI, 0);
  SetLength(VSmooth, 0);
  VertexCount:= VCSave + VAddedCount;  // убрать лишние добавленные вершины }
  for i:= 0 to VertexCount - 1 do
    Normalize(Vertices[i].Normal);
  finally
    Screen.Cursor:= crDefault;
  end;
end;

procedure TglObject.Draw_;
begin
  glPushMatrix;
    glTranslatef(Translate.X, Translate.Y, Translate.Z);

    glRotatef(Rotate.X, 1, 0, 0);
    glRotatef(Rotate.Y, 0, 1, 0);
    glRotatef(Rotate.Z, 0, 0, 1);

    glTranslatef(LocalTranslate.X + CurTranslate.X, LocalTranslate.Y + CurTranslate.Y, LocalTranslate.Z + CurTranslate.Z);

    glRotatef(LocalRotate.X, 1, 0, 0);
    glRotatef(LocalRotate.Y, 0, 1, 0);
    glRotatef(LocalRotate.Z, 0, 0, 1);

    glTranslatef(-LocalTranslate.X, -LocalTranslate.Y, -LocalTranslate.Z);

    glScalef(Scale.X, Scale.Y , Scale.Z);
    glPolygonMode(GL_FRONT_AND_BACK, PolygonMode);

    if BuildGLList then
      glCallList(GLListNumber) else
      Draw;
  glPopMatrix;
end;

procedure TGLObject.Draw;
var
  i: integer;
begin
{  if Assigned(BeforeDrawingProc) then
    BeforeDrawingProc(Self);}
  glInterleavedArrays(GL_T2F_N3F_V3F, 0, Vertices[0]);
  if Bounding then
    DrawBounding else
    begin
      for i:= 0 to FaceGroupCount - 1 do
        begin
          with FaceGroups[i] do
          if Material = nil then
            begin
              glDisable(GL_Texture_2D);
              DefaultMaterial.Apply;
            end else
            if Material is TMaterial then
              begin
                Material.Apply;
                if Assigned(Material.Texture) and (Material.Texture is TTexture) and Mapped then
                  Material.Texture.Apply else
                  glDisable(GL_TEXTURE_2D);
              end;
          glDrawElements(GL_TRIANGLES, FaceGroups[i].FaceCount*3, GL_UNSIGNED_SHORT,
                                             Faces[FaceGroups[i].OriginFace]);
(*          DisableDepthTest:= True;
          FaceGroups[i].Material.Apply;
          glDrawElements(GL_TRIANGLES, FaceGroups[i].FaceCount*3, GL_UNSIGNED_SHORT,
                                         Faces{Render}[FaceGroups[i].OriginFace]); *)
        end;
    end;
end;

procedure TglObject.Render;
begin
  if not BuildGLList then
    Exit;                     // рисуем без поддержки списков OpenGL
  Screen.Cursor:= crHourGlass;
  try
    glDeleteLists(GLListNumber, 1);
//  glInterleavedArrays(GL_T2F_N3F_V3F, 0, Vertices[0]);
    FGLListNumber:= glGenLists(1);
    glNewList(GLListNumber, GL_COMPILE);
    glPushMatrix;
    glMultMatrixf(@Matrix);
    Draw;
    glPopMatrix;
    glEndList;
  finally
    Screen.Cursor:= crDefault;
  end;
//  SetLength(FacesRender, 0);
//  VertexCount:= VCSave;  // удалить вершины, добавленные при Smoothing
end;

procedure TglObject.Paint;
var
  i,j,k: integer;
  SaveShadow: boolean;
  ShadowMatrix: array [0..15] of glFloat;
  VW: TVectorW;
  normal: TVector;
  Lights: array of boolean;

procedure generateShadowMatrix(var ShadowMatrix : Array of glFloat; const normal, point : TVector;
                              Light: TVectorW);
var
  d, dot : single;

begin
  d:= -normal.X * point.X - normal.Y * point.Y - normal.Z * point.Z;
  dot:= normal.X * Light.Vector.X  + normal.Y * Light.Vector.Y +
                                      normal.Z * Light.Vector.Z + d * Light.W;

  ShadowMatrix[0] := -Light.Vector.X * normal.X + dot;
  ShadowMatrix[4] := -Light.Vector.X * normal.Y;
  ShadowMatrix[8] := -Light.Vector.X * normal.Z;
  ShadowMatrix[12]:= -Light.Vector.X * d;
  ShadowMatrix[1] := -Light.Vector.Y * normal.X;
  ShadowMatrix[5] := -Light.Vector.Y * normal.Y + dot;
  ShadowMatrix[9] := -Light.Vector.Y * normal.Z;
  ShadowMatrix[13]:= -Light.Vector.Y * d;
  ShadowMatrix[2] := -Light.Vector.Z * normal.X;
  ShadowMatrix[6] := -Light.Vector.Z * normal.Y;
  ShadowMatrix[10]:= -Light.Vector.Z * normal.Z + dot;
  ShadowMatrix[14]:= -Light.Vector.Z * d;
  ShadowMatrix[3] := -Light.W * normal.X;
  ShadowMatrix[7] := -Light.W * normal.Y;
  ShadowMatrix[11]:= -Light.W * normal.Z;
  ShadowMatrix[15]:= -Light.W * d + dot;
end;


begin
  if not Visible then
    Exit;
  if not GetShadow or (Scene.RenderMode = GL_FEEDBACK) then
    begin
      if Scene.RenderMode = GL_FEEDBACK then
        glPassThrough(single(Self));
      Draw_;
    end  else
    begin
      glClear(GL_STENCIL_BUFFER_BIT);                 // Clear the stencil buffer the first time
      glEnable(GL_STENCIL_TEST);                      // Turn on the stencil buffer test
      glStencilFunc(GL_ALWAYS, 1, 0);                 // тест буфера трафарета проходит всегда
      glStencilOp(GL_KEEP, GL_KEEP, GL_REPLACE);      //

      SetLength(Lights, MaxLights);
      for i:= 0 to MaxLights - 1 do
        Lights[i]:= Scene.Lighting.Enabled[i];

      Scene.LightsOff;                                // выключить все источники света
      Draw_;          // теперь объект нарисован 'в темноте', а двумерный буфер трафарета заполнен 1(второй параметр glStencilFunc)

          // включить свет
      for i:= 0 to MaxLights - 1 do
        if Lights[i] then
          glEnable(GL_LIGHT0 + i);
      SetLength(Lights, 0);

      glDisable(GL_DEPTH_TEST);
      glColorMask(GL_FALSE, GL_FALSE, GL_FALSE, GL_FALSE);  // Disable the color buffer
      glStencilFunc(GL_ALWAYS, 2, 0);
      glStencilOp(GL_KEEP, GL_KEEP, GL_REPLACE);

       for i:= 0 to MaxLights - 1 do
         begin
           if not GLIsEnabled(GL_LIGHT0 + i) then
             Continue;

           for k:= 0 to FaceCount - 1 do
             begin
               glPushMatrix();
               glGetLightfv(GL_LIGHT0 + i, GL_POSITION, @VW);
               normal:= GetNormal(Vertices[Faces[k].A].Vector, Vertices[Faces[k].C].Vector,
                                          Vertices[Faces[k].B].Vector);
               Normalize(normal);
               generateShadowMatrix(ShadowMatrix, normal, Vertices[Faces[0].A].Vector, VW);
               glMultMatrixf(@ShadowMatrix);               // Add the shadow matrix to the ModelView
               with Scene do
                 for j:= 0 to ObjectCount - 1 do
                   if (Objects[j] <> Self) and CastShadow then
                     begin
                       SaveShadow:= Objects[j].GetShadow;
                                       //  отключить тень, иначе зацикливание
                       Objects[j].GetShadow:= False;
                       Objects[j].Paint; // в color buffer ничего не пишется,
                                                // а в буфере трафарета на месте тени будет 2
                       Objects[j].GetShadow:= SaveShadow;
                   end;
               glPopMatrix();
             end;
         end;
      glColorMask(GL_TRUE, GL_TRUE, GL_TRUE, GL_TRUE);      // Turn the color buffer back on
      glStencilFunc(GL_EQUAL, 1, 1);
 //     glStencilFunc(GL_EQUAL, 2, 2);
      Draw_;             // в color buffer изменения будут там, где в stencil остались единицы, т.е. где нет тени,
                         // остальное будет освещено. Если раскомментировать строчку перед Draw_, получится наоборот -
                         //                             'светящаяся' тень
      glEnable(GL_DEPTH_TEST);
      glDisable(GL_STENCIL_TEST);
    end;
end;

procedure TGLObject.SetBounding(ABounding: boolean);
begin
  if FBounding = ABounding then
    Exit;
  FBounding:= ABounding;
  Render;
end;

procedure TGLObject.SetVertexCount(AVertexCount: integer);
begin
  if AVertexCount = FVertexCount then
    Exit;                                 
  SetLength(Vertices, AVertexCount);
  FVertexCount:= AVertexCount;
end;

procedure TGLObject.SetFaceCount(AFaceCount: integer);
begin
  if AFaceCount = FFaceCount then
    Exit;
  SetLength(Faces, AFaceCount);
  FFaceCount:= AFaceCount;
end;

procedure TGLObject.SetFaceGroupCount(AFaceGroupCount: integer);
begin
  if AFaceGroupCount = FFaceGroupCount then
    Exit;
  SetLength(FaceGroups, AFaceGroupCount);
  FFaceGroupCount:= AFaceGroupCount;
end;

function TGLObject.GetMapped: boolean;
var
  i: integer;
begin
  Result:= False;
  for i:= 0 to VertexCount - 1 do
    if (Vertices[i].U <> 0) or (Vertices[i].V <> 0) then
      begin
        Result:= True;
        Exit;
      end;
end;

function TGLObject.GetMin: TVector;
var
  i: integer;
begin
  Result:= Vector(MaxInt, MaxInt, MaxInt);
  for i:= 0 to VertexCount - 1 do
    begin
      with Vertices[i].Vector do
        begin
          if X < Result.X then Result.X:= X;
          if Y < Result.Y then Result.Y:= Y;
          if Z < Result.Z then Result.Z:= Z;
        end;
    end;
end;

function TGLObject.GetMax: TVector;
var
  i: integer;
begin
  Result:= Vector(-MaxInt, -MaxInt, -MaxInt);
  for i:= 0 to VertexCount - 1 do
    begin
      with Vertices[i].Vector do
        begin
          if X > Result.X then Result.X:= X;
          if Y > Result.Y then Result.Y:= Y;
          if Z > Result.Z then Result.Z:= Z;
        end;
    end;
end;

{function TGLObject.AddFaceGroup: TFaceGroup;
begin
  Inc(FFaceGroupCount);
  SetLength(FFaceGroups, FaceGroupCount);
  Result.Material:= Nil;
  Result.OriginFace:= 0;
  Result.FaceCount:= 0;
  FaceGroups[FaceGroupCount-1]:= Result;
end; }

procedure TGLObject.SaveToFile(f: TFileStream);
var
  i,c: integer;
  b: boolean;
  ind: smallint;
  w: word;
begin
  if (VertexCount = 0) or (FaceCount = 0) then
    Exit;
  w:= 0;
  WriteString(f, Name);            // имя объекта
  f.Write(VertexCount, SizeOf(VertexCount));
  c:= SizeOf(TVector);
  for i:= 0 to VertexCount - 1 do
    f.Write(Vertices[i].Vector, c); // координаты вершин

  f.Write(FaceCount, SizeOf(FaceCount));
  c:= SizeOf(TFace);
  for i:= 0 to FaceCount - 1 do
    f.Write(Faces[i], c);

  b:= Mapped;
  f.Write(b, SizeOf(b));
  c:= SizeOf(single) * 2;
  if b then
    for i:= 0 to VertexCount - 1 do
      f.Write(Vertices[i].U, c);

  f.Write(FaceGroupCount, SizeOf(FaceGroupCount));
  for i:= 0 to FaceGroupCount - 1 do
    begin
      if FaceGroups[i].Material = nil then
        ind:= -1 else
        ind:= Scene.Materials.MaterialIndexOf(FaceGroups[i].Material);
      f.Write(ind, SizeOf(ind));
      f.Write(FaceGroups[i].OriginFace, SizeOf(FaceGroups[i].OriginFace)); // начальный фейс
      f.Write(FaceGroups[i].FaceCount, SizeOf(FaceGroups[i].FaceCount));   // кол-во фейсов
    end;

{  if Smooth <> nil then
    begin
      ChunkType:= SMOOTH_GROUP; ChunkSize:= (High(Smooth) + 1) * 4 + 6;
      f.Write(ChunkType, SizeOf(ChunkType)); f.Write(ChunkSize, SizeOf(ChunkSize));
      f.Write(Smooth[0], (High(Smooth) + 1) * SizeOf(cardinal));
    end;  }

  f.Write(Matrix, SizeOf(Matrix));   //  построенная матрица

  f.Write(Visible, SizeOf(Visible));
  f.Write(Frozen, SizeOf(Frozen));
  f.Write(Bounding, SizeOf(Bounding));

  f.Write(Translate, SizeOf(Translate));
  f.Write(Rotate, SizeOf(Rotate));
  f.Write(Scale, SizeOf(Scale));
  f.Write(PolygonMode, SizeOf(PolygonMode));

  if Version > 100 then
    begin
      f.Write(GetShadow, SizeOf(GetShadow));
      f.Write(CastShadow, SizeOf(CastShadow));
    end;  
end;

procedure TGLObject.ReadFromFile(f: TFileStream);
var
  i,c: integer;
  b: boolean;
  ind: smallint;
begin
  Name:= ReadString(f);            // имя объекта
  f.Read(c, SizeOf(c));
  VertexCount:= c;
  c:= SizeOf(TVector);
  for i:= 0 to VertexCount - 1 do
    f.Read(Vertices[i].Vector, c); // координаты вершин

  f.Read(c, SizeOf(c));
  FaceCount:= c;
  c:= SizeOf(TFace);
  for i:= 0 to FaceCount - 1 do
    f.Read(Faces[i], c);

  f.Read(b, SizeOf(b));
  c:= SizeOf(single) * 2;
  if b then
    for i:= 0 to VertexCount - 1 do
      f.Read(Vertices[i].U, c);

  f.Read(c, SizeOf(c));
  FaceGroupCount:= c;
  for i:= 0 to FaceGroupCount - 1 do
    begin
      f.Read(ind, SizeOf(ind));
      if (ind < 0) or (ind >= Scene.Materials.MatCount) then
        FaceGroups[i].Material:= nil else
        FaceGroups[i].Material:= Scene.Materials[ind];
      f.Read(FaceGroups[i].OriginFace, SizeOf(FaceGroups[i].OriginFace)); // начальный фейс
      f.Read(FaceGroups[i].FaceCount, SizeOf(FaceGroups[i].FaceCount));   // кол-во фейсов
    end;

  f.Read(Matrix, SizeOf(Matrix));   //  построенная матрица

  f.Read(Visible, SizeOf(Visible));
  f.Read(Frozen, SizeOf(Frozen));
  f.Read(FBounding, SizeOf(FBounding));

  f.Read(Translate, SizeOf(Translate));
  f.Read(Rotate, SizeOf(Rotate));
  f.Read(Scale, SizeOf(Scale));
  f.Read(PolygonMode, SizeOf(PolygonMode));
  if Scene.FileVersion > 100 then
    begin
      f.Read(GetShadow, SizeOf(GetShadow));
      f.Read(CastShadow, SizeOf(CastShadow));
    end;
end;

(*function TGLObject.Separate(FaceNumber: word): boolean;
var
  SeprVert: array of boolean;
  i: integer;
  SeprFace: array of boolean;
  Del, first: boolean;
  ind, count: word;

function CanSeparate: boolean;
var
  i: integer;
  AddedFace: boolean;

procedure AddVert(Vert: word);
begin
  SeprVert[Vert]:= True;
  AddedFace:= True;
end;

procedure AddFace(Face: TFace);
begin
  if not SeprVert[Face.A] then
    AddVert(Face.A);
  if not SeprVert[Face.B] then
    AddVert(Face.B);
  if not SeprVert[Face.C] then
    AddVert(Face.C);
end;

begin
  Result:= False;
  if (FaceCount = 0) or (VertexCount = 0) then
    Exit;
  SetLength(SeprFace, FaceCount);    // выделить память под флаги, выделен face или нет
  ZeroMemory(SeprFace, FaceCount);   // ничего пока не выделено
  SetLength(SeprVert, VertexCount);    // выделить max память под точки
  ZeroMemory(SeprVert, VertexCount);   //
// заносим первые 3 точки из первого фейса
  SeprVert[Faces[FaceNumber].A]:= True; SeprVert[Faces[FaceNumber].B]:= True;
  SeprVert[Faces[FaceNumber].C]:= True; SeprFace[FaceNumber]:= True;       // добавить первый фейс
  repeat
    AddedFace:= False;
    for i:= 0 to FaceCount - 1 do
      begin
// если точки из рассматриваемого фейса есть в выбранных точках, значит этот фейс
// соприкасается с другими выбранными
        if SeprVert[Faces[i].A] or SeprVert[Faces[i].B] or SeprVert[Faces[i].C] then
          begin
            AddFace(Faces[i]);        // добавить точки из этого фейса в выбранные
            SeprFace[i]:= True;       // добавить следующий фейс
          end;
      end;
  until not AddedFace;
  for i:= 0 to FaceCount - 1 do
    if not SeprFace[i] then
      begin
        Result:= True;
        Exit;
      end;
  SetLength(SeprFace, 0);    // освободить память под флаги фейсов
  SetLength(SeprVert, 0);    // освободить память под флаги точек
end;

procedure DeleteVerts;
var
  i: integer;
begin
  repeat
    Del:= False; first:= True; //count:= 0;
    for i:= 0 to VertexCount - 1 do
      if SeprVert[i] then      // если идет помеченная точка
        begin
          if first then        // если впервые попала помеченная точка
            begin
              ind:= i;         // сохранить ее порядковый номер
              count:= 1;       // счетчик в 1
              first:= False;   // сбросить флаг
            end else
            Inc(count);        // если не впервые, увеличить счетчик
        end else
        begin                  // точка не помечена
          if not first then    // конец блока помеченных точек
            begin
            // удалить помеченные точки
              Move(Vertices[VertexCount-ind-count+1], Vertices[ind], count * SizeOf(TVertex));
            // также переместить флаги
              Move(SeprVert[VertexCount-ind-count+1], SeprVert[ind], count);
              VertexCount:= VertexCount - count;  //  уменьшить кол-во точек
              SetLength(SeprVert, VertexCount);   //  и массив флагов
              Del:= True;
              Break;
            end;
        end;
  until not Del;
end;
// процедура корректирует FaceGroups; ind - номер первого фейса; count - их количество
procedure CorrectFaceGroups;
var
  i,j: integer;
begin
  for i:= ind to ind + count - 1 do
    for j:= 0 to FaceGroupCount - 1 do
      with FaceGroups[j] do
        if (i >= OriginFace) and (i < OriginFace + FaceCount) then
          begin
            if i = OriginFace then
              Inc(OriginFace);
            Dec(FaceCount);
            Break;
          end;
  for i:= 0 to FaceGroupCount - 1 do
    with FaceGroups[i] do
      if OriginFace > ind + count - 1 then
        Dec(OriginFace, count);
end;

procedure DeleteFaces;
var
  i: integer;
begin
  repeat
    Del:= False; first:= True; //count:= 0;
    for i:= 0 to FaceCount - 1 do
      if SeprFace[i] then      // если идет помеченный фейс
        begin
          if first then        // если впервые попала помеченный фейс
            begin
              ind:= i;         // сохранить его порядковый номер
              count:= 1;       // счетчик в 1
              first:= False;   // сбросить флаг
            end else
            Inc(count);        // если не впервые, увеличить счетчик
        end else
        begin                  // фейс не помечен
          if not first then    // конец блока помеченных фейсов
            begin
            // удалить помеченные фейсы
              Move(Faces[FaceCount-ind-count+1], Faces[ind], count * SizeOf(TFace));
            // также переместить флаги
              Move(SeprFace[FaceCount-ind-count+1], SeprFace[ind], count);
              FaceCount:= FaceCount - count;  //  уменьшить кол-во фейсов
              SetLength(SeprFace, FaceCount);   //  и массив флагов
              Del:= True;
              CorrectFaceGroups;
              Break;
            end;
        end;
  until not Del;
end;

begin
  if not CanSeparate then
    Exit;
  DeleteFaces;  //  удаляет помеченные фейсы из Faces
  DeleteVerts;  //  удаляет помеченные точки из Vertices
//  эти массивы больше не нужны
  SetLength(SeprFace, 0);    // освободить память под флаги фейсов
  SetLength(SeprVert, 0);    // освободить память под флаги точек
// оставшиеся фейсы могут ссылаться на уже несуществующие точки,нужно отредактировать их
// ind - номер первой удаленной точки; count - кол-во этих точек
// значит, если фейс ссылается на точку с номером > ind, это значение надо уменьшить на count
  for i:= 0 to FaceCount - 1 do
    begin
      if Faces[i].A > ind then Dec(Faces[i].A, count);
      if Faces[i].B > ind then Dec(Faces[i].B, count);
      if Faces[i].C > ind then Dec(Faces[i].C, count);
    end;
end; *)

// ====================== TGLScene ============================================

function TGLScene.InitOpenGL(DC: hDC; var GLRC: HGLRC): TOGL_InitError;
var
  PFD: TPIXELFORMATDESCRIPTOR;
  PixelFormat: integer;
begin
  Result:= NoError;
  FillChar(PFD, SizeOf(PFD), 0);
  PFD.nSize:= SizeOf(PFD);
 // PFD.nVersion:= 1;
 // PFD.cColorBits:= 32;
  PFD.cDepthBits:= 32;
  PFD.cStencilBits:= 1;
  PFD.dwFlags:= PFD_DRAW_TO_WINDOW or PFD_SUPPORT_OPENGL or PFD_DOUBLEBUFFER;
  PixelFormat:= ChoosePixelFormat(DC, @pfd);
  if PixelFormat = 0 then
    begin
      Result:= ChoosePixelFormatError;
      Exit;
    end;
  if not SetPixelFormat(DC, PixelFormat, @PFD) then
    begin
      Result:= SetPixelFormatError;
      Exit;
    end;
  GLRC := wglCreateContext(DC);
  if GLRC = NULL then
    begin
      Result:= CreateContextError;
      Exit;
    end;
 if not wglMakeCurrent(DC, GLRC) then
    begin
      Result:= MakeCurrentError;
      Exit;
    end;
end;

procedure TGLScene.WndProcedure(var Message: TMessage);
var
  ps: TPaintStruct;
  glSceneSave: TglScene;
begin
  case Message.Msg of
    WM_PAINT:
      begin
        glSceneSave:= CurScene_;
        SetCurScene(Self);
        BeginPaint(Screen.Handle, ps);
        Draw_;
        EndPaint(Screen.Handle, ps);
        SetCurScene(glSceneSave);
      end;
    WM_SIZE:
      begin
        glSceneSave:= CurScene_;
        SetCurScene(Self);
        ReSize;
        SetCurScene(glSceneSave);
      end;
    WM_ERASEBKGND:
      begin
        glSceneSave:= CurScene_;
        SetCurScene(Self);
        Message.Msg:= 1;
        SetCurScene(glSceneSave);
      end;
{    WM_DROPFILES:
      begin
        Count:= DragQueryFile(TWMDropFiles(Message).Drop, DWORD(-1), nil, 0);
        if Count > 0 then
          begin
            DragQueryFile(TWMDropFiles(Message).Drop, 0, Buffer, MAX_PATH);
            DragFinish(TWMDropFiles(Message).Drop);
            Message.Result:= 0;
            LoadFromFile(Buffer);
          end;
      end;}
  end;
  WindowProcSave(Message);
end;

constructor TGLScene.Create(GLScreen: TWinControl);
var
  i: integer;
begin
  inherited Create;
  FScreen:= GLScreen;
  FDC:= GetDC(Screen.Handle);
  FErrorCode:= InitOpenGL(DC, GLRC);
  if ErrorCode <> NoError then
    begin
      ReleaseDC(Screen.Handle, DC);
      Exit;
    end;

  glGetIntegerv(GL_MAX_TEXTURE_SIZE, @MaxTextureSize);
  glGetIntegerv(GL_MAX_LIGHTS, @MaxLights);
  glEnable(GL_DEPTH_TEST);
  glEnable(GL_LIGHTING);
  Lighting.TwoSide:= True;

//  glEnable(GL_NORMALIZE);
  glEnable(GL_LINE_SMOOTH);
  glEnable(GL_POINT_SMOOTH);
  glEnable(GL_POLYGON_SMOOTH);
//  glDepthFunc(GL_LESS);
//  glEnable(GL_CULL_FACE);
 //glFrontFace(GL_CCW);

  glHint(GL_LINE_SMOOTH_HINT, GL_NICEST);
  glHint(GL_PERSPECTIVE_CORRECTION_HINT, GL_NICEST);
  glHint(GL_POINT_SMOOTH_HINT, GL_NICEST);
  glHint(GL_POLYGON_SMOOTH_HINT, GL_NICEST);

  FObjectCount:= 0;
  RenderMode:= GL_RENDER;

  fovy:= 90;
  FAutoAspect:= True;
  Aspect:= Screen.ClientWidth/Screen.ClientHeight;
  zNear:= 2;
  zFar:= 10000;
  EyePoint:= Vector(0, 0, 0);
  RefPoint:= Vector(0, 0, -1);
  UpVector:= Vector(0, 1, 0);

  DefaultLight:= Lighting[1];
  Materials:= TMaterials.Create;
  BG:= TBackground.Create;
  MotionCount:= 0;
  Motions:= Nil;
  Resize;

  WindowProcSave:= Screen.WindowProc;
  Screen.WindowProc:= WndProcedure;

  i:= 1;
  SetLength(Power2, 1); //Round(log2(MaxTextureSize)));
  Power2[0]:= 1;
  with Jitter do
    begin
      Enabled:= False;       // будет ли сцена сглаживаться
      Value:= 10;
      PassCount:= 8;             // кол-во проходов для сглаживания
    end;
  repeat
    Inc(i);
    SetLength(Power2, i);
    Power2[i-1]:= Power2[i-2] * 2;
  until Power2[i-1] >= MaxTextureSize;
  CurScene_:= Self;

end;

destructor TGLScene.Destroy;
begin
  BG.Free;
  ClearAll;

  wglMakeCurrent(0, 0);
  wglDeleteContext(GLRC);
  ReleaseDC(Screen.Handle, DC);
  DeleteDC(DC);
  Screen.WindowProc:= WindowProcSave;

  if CurScene_ = Self then
    CurScene_:= Nil;
  inherited Destroy;
end;

function TGLScene.glObject: TglObject;
begin
  Result:= TGLObject.Create;
end;

procedure TGLScene.Translate(X,Y,Z: single);
var
  i: integer;
begin
  for i:= 0 to ObjectCount - 1 do
    if not Objects[i].Frozen then
      Objects[i].Translate:= AddVectors(Objects[i].Translate, Vector(X,Y,Z));
  if not Assigned(Texts) then
    Exit;
  for i:= 0 to Texts.TextCount - 1 do
    if not Texts.Texts[i].Frozen then
      Texts.Texts[i].Translate:= AddVectors(Texts.Texts[i].Translate, Vector(X,Y,Z));
end;

procedure TGLScene.Rotate(X,Y,Z: single);
var
  i: integer;
begin
  for i:= 0 to ObjectCount - 1 do
    if not Objects[i].Frozen then
      Objects[i].Rotate := AddVectors(Objects[i].Rotate, Vector(X,Y,Z));
  if not Assigned(Texts) then
    Exit;
  for i:= 0 to Texts.TextCount - 1 do
    if not Texts.Texts[i].Frozen then
      Texts.Texts[i].Rotate:= AddVectors(Texts.Texts[i].Rotate, Vector(X,Y,Z));
end;

procedure TGLScene.Scale(X,Y,Z: single);
var
  i: integer;
begin
  for i:= 0 to ObjectCount - 1 do
//    if not Objects[i].Frozen then
      Objects[i].Scale := AddVectors(Objects[i].Scale, Vector(X,Y,Z));
  if not Assigned(Texts) then
    Exit;
  for i:= 0 to Texts.TextCount - 1 do
   // if not Texts.Texts[i].Frozen then
      Texts.Texts[i].Scale:= AddVectors(Texts.Texts[i].Scale, Vector(X,Y,Z));
end;

procedure TglScene.GetNormals;
var
  i: integer;
begin
  for i:= 0 to ObjectCount - 1 do
    Objects[i].GetNormals;
end;

procedure TglScene.RenderObject(glObject: TglObject);
begin
  glObject.Render;
end;

procedure TglScene.Render;
var
  i: integer;
begin
 // Screen.Cursor:= crHourGlass;
 // try
    for i:= 0 to Materials.TexCount - 1 do
      Materials.Textures[i].Build;

    for i:= 0 to ObjectCount - 1 do
      {Objects[i].} RenderObject(Objects[i]);
    ReSize;

//   finally
//    Screen.Cursor:= crDefault;
 // end;
end;

procedure TGLScene.LookAt;
{var
  mt: array[0..3, 0..3] of single; }
var
 // A,B,C,D: single;
  x1,x2,x3,y1,y2,y3,z1,z2,z3: single;
begin
//  glGetFloatv(GL_MODELVIEW_MATRIX, @mt);
  glLoadIdentity;
//  glGetFloatv(GL_MODELVIEW_MATRIX, @mt);
  gluLookAt(EyePoint.X, EyePoint.Y, EyePoint.Z, RefPoint.X, RefPoint.Y, RefPoint.Z,
                                           UpVector.X, UpVector.Y, UpVector.Z);
  x1:= EyePoint.X; y1:= EyePoint.Y; z1:= EyePoint.Z;
  x2:= RefPoint.X; y2:= RefPoint.Y; z2:= RefPoint.Z;
  x3:= UpVector.X; y3:= UpVector.Y; z3:= UpVector.Z;

  NormalVector.X:= y1 * (z2 - z3) + y2 * (z3 - z1) + y3 * (z1 - z2);
  NormalVector.Y:= z1 * (x2 - x3) + z2 * (x3 - x1) + z3 * (x1 - x2);
  NormalVector.Z:= x1 * (y2 - y3) + x2 * (y3 - y1) + x3 * (y1 - y2);

  Normalize(NormalVector);

//  D:= x1 * (y2 * z3 - y3 * z2) + x2 * (y3 * z1 - y1 * z3) + x3 * (y1 * z2 - y2 * z1);
//  glGetFloatv(GL_MODELVIEW_MATRIX, @mt);
end;

procedure TGLScene.LoadFromFile(FName: string);
var
  Ext: string;
begin
  if not FileExists(FName) then
    Exit;
//  ClearAll;
  Ext:= UpperCase(ExtractFileExt(FName));
  if Ext = '.3DS' then
    Read3DSFile(FName) else
    if Ext = '.3DA' then
      Read3DAFile(FName) else
      Exit;
  FileName:= FName;
end;

procedure TGLScene.AddObject(GLObject: TGLObject);
begin
  GLObject.Scene:= Self;
  Inc(FObjectCount);
  SetLength(Objects, ObjectCount);
  Objects[ObjectCount-1]:= GLObject;
end;

procedure TGLScene.DeleteObject(DelObject: TGLObject);
var
  i: integer;
begin
  for i:= 0 to ObjectCount do
    if Objects[i] = DelObject then
      begin
        Objects[i].Free;
        Move(Objects[i+1], Objects[i], SizeOf(TGLObject) * (ObjectCount - i - 1));
        Dec(FObjectCount);
        SetLength(Objects, ObjectCount);
        Exit;
      end;
end;

procedure TGLScene.ClearAll;
var
  i: integer;
begin
  for i:= 0 to ObjectCount - 1 do
    Objects[i].Free;
  FObjectCount:= 0;
  SetLength(Objects, 0);

//  Textures.Free;
  Materials.Free;

  for i:= 0 to MotionCount - 1 do
    with Motions[i] do
      begin
        SetLength(Translation, 0);
        TransKeyCount:= 0;
        SetLength(Rotation, 0);
        RotKeyCount:= 0;
        SetLength(Scaling, 0);
        ScaleKeyCount:= 0;
      end;
  SetLength(Motions, 0);
  MotionCount:= 0;
end;

procedure TGLScene.Paint;
begin
  InvalidateRect(Screen.Handle, nil, False);
end;

procedure TglScene.ReSize;
begin
  if AutoAspect then
    Aspect:= Screen.ClientWidth/Screen.ClientHeight;
  glViewport(0, 0, Screen.ClientWidth, Screen.ClientHeight);
  BG.Render;
  Perspective;
  Paint;
end;

procedure TglScene.Draw_;
var
  t: DWORD;
begin
  t:= GetTickCount;
  BG.Paint;

  Draw;

  SwapBuffers(wglGetCurrentDC);
  try
    FPS:= 1000 / (GetTickCount - t);
  except
    FPS:= MaxInt;
  end;
end;

procedure TglScene.Draw;
var
  i: integer;
  jit: integer;
  UnitPerPixel: single;
  JC: byte;
  JP: integer;
  C: single;
  UpVect: TVector;
begin

 // glCallList(BG.ListNumber);

  if Jitter.Enabled then
    begin
      glClear(GL_ACCUM_BUFFER_BIT);
      UnitPerPixel:= 1 / PixelsPerUnit;
      UpVect:= UpVector;
      Normalize(UpVect);

      if Jitter.PassCount in JitterC then
        JC:= Jitter.PassCount else
        JC:= 8;
      case JC of
        2: JP:= 0;
        3: JP:= 2;
        4: JP:= 2+3;
        8: JP:= 2+3+4;
        15: JP:= 2+3+4+8;
        24: JP:= 2+3+4+8+15;
        66: JP:= 2+3+4+8+15+24;
      end;
    end else
    JC:= 1;
  for jit:= JP to JP + JC - 1 do
    begin
      glCallList(BG.ListNumber);     // !!!!!!!!!!!!!!!!!!!!!!
      if Jitter.Enabled then
        begin
          glPushMatrix;
// перемещение вправо, влево
          C:= JitterPoints[jit].x * UnitPerPixel * Screen.ClientWidth * Jitter.Value /  10000;
          glTranslatef(NormalVector.X * C, NormalVector.Y * C, NormalVector.Z * C);
// up, down
          C:= JitterPoints[jit].y * UnitPerPixel * Screen.ClientHeight * Jitter.Value /  10000;
          glTranslatef(UpVect.X * C, UpVect.Y * C, UpVect.Z * C);

        end;

     for i:= ObjectCount - 1 downto 0 do
       Objects[i].Paint;

   //   for i:= 0 to ObjectCount - 1 do
     //   Objects[i].Paint;

// здесь будем выводить текст
      if Assigned(Texts) then
        Texts.Draw;

      if Jitter.Enabled then
        begin
         glPopMatrix;
         if jit = JP then
           glAccum(GL_LOAD, 1 /JC) else
           glAccum(GL_ACCUM, 1 /JC);
         end;
    end;
  if Jitter.Enabled then
    glAccum (GL_RETURN, 1);
end;

function TGLScene.GetRenderMode: cardinal;
begin
  glGetIntegerv(GL_RENDER_MODE, @Result);
end;

procedure TGLScene.SetRenderMode(ARenderMode: cardinal);
begin
  glRenderMode(ARenderMode);
end;

function TGLScene.GetMin: TVector;
var
  i: integer;
  M: TVector;
begin
  Result:= Vector(MaxInt, MaxInt, MaxInt);
  for i:= 0 to ObjectCount - 1 do
    with Objects[i] do
      begin
        M:= Min;
        if M.X < Result.X then Result.X:= M.X;
        if M.Y < Result.Y then Result.Y:= M.Y;
        if M.Z < Result.Z then Result.Z:= M.Z;
      end;
end;

function TGLScene.GetMax: TVector;
var
  i: integer;
  M: TVector;
begin
  Result:= Vector(-MaxInt, -MaxInt, -MaxInt);
  for i:= 0 to ObjectCount - 1 do
    with Objects[i] do
      begin
        M:= Max;
        if M.X > Result.X then Result.X:= M.X;
        if M.Y > Result.Y then Result.Y:= M.Y;
        if M.Z > Result.Z then Result.Z:= M.Z;
      end;
end;

procedure TGLScene.SaveJpeg(f: TFileStream);
var
  BitMap: TBitMap;
  Jpeg: TJpegImage;
  ChunkType: word;
  ChunkSize: cardinal;
  SavePos: integer;
  c: cardinal;
  otn: single;
begin
  if not PutPictureInFile then
    begin
      f.Position:= f.Size;
      c:= 0;
      f.Write(c, SizeOf(c));
      Exit;
    end;

  BitMap:= TBitMap.Create;
 { case PutPictureInFile of
    pfConst: begin
               BitMap.Width:= PictureDim.X;
               BitMap.Height:= PictureDim.Y;
             end;
    pfScreen: begin
                BitMap.Width:= Screen.ClientWidth;
                BitMap.Height:= Screen.ClientHeight;
              end;
  end;                                      }

  if (Screen.ClientWidth > 300) or (Screen.ClientHeight > 300) then
    begin
      if Screen.ClientWidth >= Screen.ClientHeight then
        begin
          otn:= Screen.ClientWidth / 300;
          BitMap.Width:= Round(Screen.ClientWidth / otn);
          BitMap.Height:= Round(Screen.ClientHeight / otn);
        end else
        if Screen.ClientHeight > Screen.ClientWidth then
        begin
          otn:= Screen.ClientHeight / 300;
          BitMap.Height:= Round(Screen.ClientHeight / otn);
          BitMap.Width:= Round(Screen.ClientWidth / otn);
        end;
    end else
    begin
      BitMap.Width:= Screen.ClientWidth;
      BitMap.Height:= Screen.ClientHeight;
    end;

  StretchBlt(BitMap.Canvas.Handle, 0, 0, BitMap.Width, BitMap.Height, DC, 0, 0,
                             Screen.ClientWidth, Screen.ClientHeight, SRCCOPY);
  Jpeg:= TJpegImage.Create; //  Jpeg.CompressionQuality:= 50;
  Jpeg.Assign(BitMap);
  BitMap.Free;

  c:= f.Position;
  Jpeg.SaveToStream(f);

  f.Write(c, SizeOf(c));
  Jpeg.Free;
end;

procedure TGLScene.SaveBMP(FName: string);
var
  BitMap: TBitMap;
begin
  if FileName = '' then
    Exit;
{  if PutPictureInFile = pfNo then
    Exit;}

  BitMap:= TBitMap.Create;
//  BitMap.Width:= 128;
//  BitMap.Height:= 128;
{  case PutPictureInFile of
    pfConst: begin
               BitMap.Width:= PictureDim.X;
               BitMap.Height:= PictureDim.Y;
             end;
    pfScreen: begin
                BitMap.Width:= Screen.ClientWidth;
                BitMap.Height:= Screen.ClientHeight;
              end;
  end;  }
  StretchBlt(BitMap.Canvas.Handle, 0, 0, BitMap.Width, BitMap.Height, DC, 0, 0,
                             Screen.ClientWidth, Screen.ClientHeight, SRCCOPY);
  BitMap.SaveToFile(FName);
  BitMap.Free;
end;

procedure TGLScene.SaveToFile;
var
  f: TFileStream;
  ChunkType: word;
  i: integer;
  Color: TColor;
  pos,pos1: cardinal;
  w: word;
begin
  if FileName = '' then
    Exit;
  Screen.Cursor:= crHourGlass;
  try
  FileName:= ChangeFileExt(FileName, '.3da');
  if FileExists(FileName) then
    DeleteFile(FileName);
  if FileExists(FileName) then
    f:= TFileStream.Create(FileName, fmOpenWrite) else
    f:= TFileStream.Create(FileName, fmOpenWrite or fmCreate);
// пишем заголовок, что это именно 3da файл
  ChunkType:= File3DA;
  f.Write(ChunkType, SizeOf(ChunkType));
  f.Write(Version, SizeOf(Version));
// записать материалы
  Materials.SaveToFile(f);
// записать объекты
  pos:= f.Position;
  f.Seek(SizeOf(cardinal), soFromCurrent);  // оставить место для окончания записи объектов
  for i:= 0 to ObjectCount - 1 do
    Objects[i].SaveToFile(f);       // пустые объекты не пишутся
  pos1:= f.Position;
  f.Position:= pos;
  f.Write(pos1, SizeOf(pos1));
  f.Position:= pos1;               // вернуться

  LightingSaveToFile(f);

  Color:= BG.ClearColor;
  f.Write(Color, SizeOf(Color));

  f.Write(EyePoint, SizeOf(EyePoint)); f.Write(RefPoint, SizeOf(RefPoint));
  f.Write(UpVector, SizeOf(UpVector));

  f.Write(fovy, SizeOf(fovy)); f.Write(zNear, SizeOf(zNear));
  f.Write(zFar, SizeOf(zFar));
  f.Write(Aspect, SizeOf(Aspect));
  f.Write(AutoAspect, SizeOf(AutoAspect));

 // if Version > 10 then
    f.Write(Jitter, SizeOf(Jitter));

  SaveJpeg(f); 
  f.Free;
  finally
    Screen.Cursor:= crDefault;
  end;
end;

procedure TGLScene.Read3DAFile(FName: string);
var
  f: TFileStream;
  w: word;
  c,i: integer;
  pos: cardinal;
  Color: TColor;
 // Vers: word;
begin
  Screen.Cursor:= crHourGlass;
  if not FileExists(FName) then
    Exit;
  try
    f:= TFileStream.Create(FName, fmOpenRead);
    f.Read(w, SizeOf(w));
    if w <> File3DA then
      begin
        f.Free;
        ShowMessage(FName + ' is not 3DA file.');
        Exit;
      end;
  f.Read(FileVersion, SizeOf(FileVersion));
  Materials.ReadFromFile(f, ExtractFilePath(FName));
  f.Read(pos, SizeOf(pos));
  while f.Position < pos do
    NewObject.ReadFromFile(f);
  LightingReadFromFile(f);
  f.Read(Color, SizeOf(Color));
  BG.ClearColor:= Color;

  f.Read(EyePoint, SizeOf(EyePoint)); f.Read(RefPoint, SizeOf(RefPoint));
  f.Read(UpVector, SizeOf(UpVector));

  f.Read(fovy, SizeOf(fovy)); f.Read(zNear, SizeOf(zNear));
  f.Read(zFar, SizeOf(zFar));
  f.Read(Aspect, SizeOf(Aspect));
  f.Read(FAutoAspect, SizeOf(FAutoAspect));

  f.Read(Jitter, SizeOf(Jitter));

  f.Free;
  finally
    Screen.Cursor:= crDefault;
  end;
end;


procedure TGLScene.Read3DSFile(FName: string);
var
  f: TFileStream;
  ChunkType: word;
  ChunkSize: cardinal;
  Vector: TVector;
  w: word;
  SavePos: cardinal;
  GLObject: TGLObject;
  Str: string;
  i: integer;
  clr: byte;
  ColorB: TColorB;
  si: smallint;
  fl: single;
  CurrentLight: byte;
  ColorF: TColorF;
  FacesNumber: array of word;
  FaceNumberCount: word;
  TexPar: byte;
  Color: TColor;
  glLight: TLight;
  TexName: string;

function ReadWord: Word;
begin
  f.ReadBuffer(Result, SizeOf(Result));
end;

function SeekChild(ChunkType: word; ChunkSize: cardinal): cardinal;
// Function skips to next Chunk on disk by seeking the next file position

begin
  Result := 0;
  case ChunkType of
    M3DMAGIC,SMAGIC,LMAGIC,MATMAGIC,MLIBMAGIC,MDATA,AMBIENT_LIGHT,SOLID_BGND,
    DEFAULT_VIEW,MAT_ENTRY,MAT_AMBIENT,MAT_DIFFUSE,MAT_SPECULAR,MAT_SHININESS,
    MAT_SHIN2PCT,MAT_SHIN3PCT,MAT_TRANSPARENCY,MAT_XPFALL,MAT_REFBLUR,MAT_SELF_ILPCT,
    MAT_TEXMAP,MAT_TEXMASK,MAT_TEX2MAP,MAT_TEX2MASK,MAT_OPACMAP,MAT_OPACMASK,
    MAT_REFLMAP,MAT_REFLMASK,MAT_BUMPMAP,MAT_BUMPMASK,MAT_SPECMAP,MAT_SPECMASK,
    MAT_SHINMAP,MAT_SHINMASK,MAT_SELFIMAP,MAT_SELFIMASK,N_TRI_OBJECT,XDATA_SECTION,
    {XDATA_ENTRY,}KFDATA,OBJECT_NODE_TAG,CAMERA_NODE_TAG,TARGET_NODE_TAG,LIGHT_NODE_TAG,
    SPOTLIGHT_NODE_TAG,L_TARGET_NODE_TAG,AMBIENT_NODE_TAG,CMAGIC, OBJ_HIDDEN,
    Obj_Moving, Mat_Emission, Model_Ambient, Light, Look_At, Scene_Perspective, BackGround,
    MAT_GROUP:
      ; // do nothing
    M3D_VERSION:
      Result := SizeOf(Integer);
    COLOR_F:
      Result := 3 * SizeOf(Single);
    COLOR_24:
      Result := 3 * SizeOf(Byte);
    INT_PERCENTAGE:
      Result := SizeOf(SmallInt);
    FLOAT_PERCENTAGE:
      Result := SizeOf(Single);
{    MAT_MAPNAME:
      Str := ReadString;}
    MESH_VERSION:
      Result := SizeOf(Integer);
    MASTER_SCALE:
      Result := SizeOf(Single);
    LO_SHADOW_BIAS:
      Result := SizeOf(Single);
    HI_SHADOW_BIAS:
      Result := SizeOf(Single);
    SHADOW_MAP_SIZE:
      Result := SizeOf(SmallInt);
    SHADOW_SAMPLES:
      Result := SizeOf(SmallInt);
    O_CONSTS:
      Result := 12;
    V_GRADIENT:
      Result := SizeOf(Single);
    NAMED_OBJECT:
      Str := ReadString(f);
    BIT_MAP:
      Str := ReadString(f);
    FOG:
      Result := 4 * SizeOf(Single);
    LAYER_FOG         :
      Result := 3 * SizeOf(Single) + SizeOf(Integer);
    DISTANCE_CUE:
      Result := 4 * SizeOf(Single);
    N_DIRECT_LIGHT:
      Result := 12;
    DL_SPOTLIGHT:
      Result := 12 + 2 * SizeOf(Single);
    N_CAMERA:
      Result := 24 + 2 * SizeOf(Single);
    VIEWPORT_LAYOUT:
      Result := 7 * SizeOf(SmallInt);
    VIEW_TOP,
    VIEW_BOTTOM,
    VIEW_LEFT,
    VIEW_RIGHT,
    VIEW_FRONT,
    VIEW_BACK:
      Result := 12 + SizeOf(Single);
    VIEW_USER:
      Result := 12 + 4 * SizeOf(Single);
    VIEW_CAMERA:
      Str := ReadString(f);
  {  MAT_NAME:
      Str := ReadString; }
    MAT_ACUBIC:
      Result := 2 * SizeOf(Byte) + 2 * SizeOf(Integer) + SizeOf(SmallInt);
 //   POINT_ARRAY,
    POINT_FLAG_ARRAY:
      Result := ChunkSize - 6;
   { FACE_ARRAY:
      Result := ReadWord * SizeOf(SmallInt) * 4;}
{    MSH_MAT_GROUP:
      Result := ChunkSize - 6; }
    SMOOTH_GROUP:
      Result := ChunkSize - 6;
   { TEX_VERTS:
      Result := ChunkSize - 6; }
{    MESH_MATRIX:
      Result := 12 * SizeOf(Single);}
    MESH_TEXTURE_INFO:
      Result := ChunkSize - 6;
    PROC_NAME:
      Str := ReadString(f);
    DL_LOCAL_SHADOW2:
      Result := 2 * SizeOf(Single) + SizeOf(SmallInt);
    KFHDR:
      begin
        f.Seek(SizeOf(SmallInt), soFromCurrent);
//        ReadShort;
        Str := ReadString(f);
        f.Seek(SizeOf(integer), soFromCurrent);
//        ReadInteger;
      end;
    KFSEG:
      Result := 2 * SizeOf(Integer);
    KFCURTIME:
      Result := SizeOf(Integer);
  {  NODE_HDR:
      begin
        Str := ReadString;
        Result := 2 * SizeOf(SmallInt) + SizeOf(SmallInt);
      end; }
    NODE_ID:
      Result := SizeOf(SmallInt);
   { PIVOT:
      Result := 12;}
    INSTANCE_NAME:
      Str := ReadString(f);
    MORPH_SMOOTH:
      Result := SizeOf(Single);
    BOUNDBOX:
      Result := 24;
    VPDATA:
      Result := SizeOf(Integer);
  else
    Result := ChunkSize - 6;
  end;
end;

procedure CorrectFaces;
var
  i,k: integer;
  NewFaces: array of TFace;
  NewFaceCount: word;
  Moved_: array of boolean;

function Moved(w: integer): boolean;
var
  i: integer;
begin
  Result:= False;
  for i:= 0 to FaceNumberCount - 1 do
    if w = FacesNumber[i] then
      begin
        Result:= True;
        Exit;
      end;
end;

begin
  if GLObject = nil then
    Exit;
  NewFaceCount:= 0;
  SetLength(Moved_, GLObject.FaceCount);
  if FaceNumberCount <> 0 then
// перенести фейсы, описанные в группах материалов
    begin
      NewFaceCount:= FaceNumberCount;
      SetLength(NewFaces, NewFaceCount);
      for i:= 0 to NewFaceCount - 1 do
        begin
          NewFaces[i]:= GLObject.Faces[FacesNumber[i]];
          Moved_[FacesNumber[i]]:= True;
        end;
    end;

// теперь перенести фейсы из GLObject.Faces, которые не попали в описание групп мат-лов
  if FaceNumberCount < GLObject.FaceCount then
    begin
// добавить новую группу, которая будет содержать не вошедшие в группы мат-лов фейсы
      GLObject.FaceGroupCount:= GLObject.FaceGroupCount + 1;
// начало группы NewFaceCount
      GLObject.FaceGroups[GLObject.FaceGroupCount-1].OriginFace:= NewFaceCount;
      GLObject.FaceGroups[GLObject.FaceGroupCount-1].FaceCount:= GLObject.FaceCount - FaceNumberCount;
      SetLength(NewFaces, GLObject.FaceCount);

      k:= 0;
      for i:= 0 to GLObject.FaceCount - 1 do
        if not Moved_[i] then
          begin
            NewFaces[NewFaceCount + k]:= GLObject.Faces[i];
            Inc(k);
        end;
    end;

  SetLength(FacesNumber, 0);
  Move(NewFaces[0], GLObject.Faces[0], GLObject.FaceCount * SizeOf(TFace));
  FacesNumber:= Nil;
  FaceNumberCount:= 0;
  NewFaceCount:= 0;
  SetLength(NewFaces, 0);
  SetLength(Moved_, 0);
end;

procedure SeekFlags;
var
  flags: word;
const
  KeyUsesTension3DS  = $01;
  KeyUsesCont3DS     = $02;
  KeyUsesBias3DS     = $04;
  KeyUsesEaseTo3DS   = $08;
  KeyUsesEaseFrom3DS = $10;
begin
  flags := ReadWord;
  if flags = 0 then
    Exit;
  if flags and KeyUsesTension3DS > 0 then
    f.Seek(SizeOf(single), soFromCurrent);
  if flags and KeyUsesCont3DS > 0 then
    f.Seek(SizeOf(single), soFromCurrent);
  if flags and KeyUsesBias3DS > 0 then
    f.Seek(SizeOf(single), soFromCurrent);
  if flags and KeyUsesEaseTo3DS > 0 then
    f.Seek(SizeOf(single), soFromCurrent);
  if flags and KeyUsesEaseFrom3DS > 0 then
    f.Seek(SizeOf(single), soFromCurrent);
end;

type
  TMap = (TEX, TEX2, OPAC, REFL, BUMP, SPEC, SHIN, SELFI);

var
  Prnt: smallint;
  Map: TMap;
  b: boolean;

begin
  Screen.Cursor:= crHourGlass;
  GLObject:= Nil;
  CurrentLight:= 255;
  FacesNumber:= Nil;
  FaceNumberCount:= 0;
  try
    f:= TFileStream.Create(FName, fmOpenRead);
    f.Read(ChunkType, SizeOf(ChunkType));
    f.Read(ChunkSize, SizeOf(ChunkSize));
    // test header to determine whether it is a top level chunk type
    if ChunkType = M3DMAGIC then
      f.Seek(SeekChild(ChunkType, ChunkSize), soFromCurrent) else
      begin
        f.Free;
        ShowMessage(FName + ' is not 3DS file.');
        Exit;
      end;
  clr:= 10;
  while f.Position < f.Size do
  begin
    f.Read(ChunkType, SizeOf(ChunkType));
    f.Read(ChunkSize, SizeOf(ChunkSize));
    case ChunkType of
      N_TRI_OBJECT:
        begin
          if UpperCase(ExtractFileExt(FName)) = '.3DS' then
            CorrectFaces;
          GLObject:= NewObject;  // заводим новый объект
          GLObject.Name:= Str;         // последняя строка - имя объекта
         // AddObject(GLObject);
        end;
      POINT_ARRAY:
        begin                           // координаты точек
          w:= ReadWord;
          GLObject.VertexCount:= w;
          if w <> 0 then
            for i:= 0 to w - 1 do
              f.Read(GLObject.Vertices[i].Vector, SizeOf(TVector));
          ChunkType:= MDATA;            // любой тип, чтобы не делать Seek
        end;
      TEX_VERTS:
        begin                           // текстурные координаты
          w:= ReadWord;
          if w <> 0 then
            for i:= 0 to w - 1 do
              f.Read(GLObject.Vertices[i].U, SizeOf(single) * 2);
          ChunkType:= MDATA;
        end;
      FACE_ARRAY:                              // фейсы
        begin
          w:= ReadWord;
          GLObject.FaceCount:= w;
          for i:= 0 to w - 1 do
            begin
              f.Read(GLObject.Faces[i], SizeOf(TFace));
              f.Seek(2, soFromCurrent);   // пропустить флаг, который определяет Edges
            end;
          ChunkType:= MDATA;
        end;
      SMOOTH_GROUP:                     // сглаживание
        begin
          SetLength(GLObject.Smooth, (ChunkSize - 6) div 4);
          f.Read(GLObject.Smooth[0], (ChunkSize - 6) div 4 * SizeOf(cardinal));
          ChunkType:= MDATA;
        end; 
      MESH_MATRIX:
        begin
          f.Read(GLObject.Matrix[0,0], 3*SizeOf(single));
          f.Read(GLObject.Matrix[1,0], 3*SizeOf(single));
          f.Read(GLObject.Matrix[2,0], 3*SizeOf(single));
          f.Read(GLObject.Matrix[3,0], 3*SizeOf(single));
          if Uppercase(ExtractFileExt(FName)) = '.3DA' then
            GLObject.MatrixBuilt:= True;
 //         GLObject.LocalMatrix[3,3]:= 1;
          ChunkType:= MDATA;
        end;
      OBJ_HIDDEN: GLObject.Visible:= False;
      OBJ_FROZEN: GLObject.Frozen:= True;
      Obj_Bounding: GLObject.FBounding:= True;
      Obj_Moving:
        with GLObject do
        begin
          f.Read(Translate, SizeOf(Translate));
          f.Read(Rotate, SizeOf(Rotate));
          f.Read(Scale, SizeOf(Scale));
        end;

      MAT_ENTRY:                 // новый материал
        Materials.NewMaterial;
      MAT_NAME:
        begin
          Materials[Materials.MatCount-1].Name:= ReadString(f);
          ChunkType:= MDATA;
        end;
      MAT_AMBIENT: clr:= 0;
      MAT_DIFFUSE: clr:= 1;
      MAT_SPECULAR: clr:= 2;
      Mat_Emission: clr:= 3;
      COLOR_24:
        begin
          f.Read(ColorB, 3);
          with Materials[Materials.MatCount-1] do
          case clr of
            0: Ambient:= RGB(ColorB.R, ColorB.G, ColorB.B);
            1: Diffuse:= RGB(ColorB.R, ColorB.G, ColorB.B);
            2: Specular:= RGB(ColorB.R, ColorB.G, ColorB.B);
            3: Emission:= RGB(ColorB.R, ColorB.G, ColorB.B);
          end;
          clr:= 10;
          ChunkType:= MDATA;
        end;
      COLOR_F:
        begin
          f.Read(ColorF, 3 * SizeOf(single));
          with Materials[Materials.MatCount-1] do
          case clr of
            0: Ambient:= ColorFToTColor(ColorF);
            1: Diffuse:= ColorFToTColor(ColorF);
            2: Specular:= ColorFToTColor(ColorF);
            3: Emission:= ColorFToTColor(ColorF);
          end;
          clr:= 10;
          ChunkType:= MDATA;
        end;
      MAT_SHININESS:
        begin
          f.Read(ChunkType, SizeOf(ChunkType));
          f.Read(ChunkSize, SizeOf(ChunkSize));
          case ChunkType of
            INT_PERCENTAGE:
              begin
                f.Read(si, SizeOf(si));
                Materials[Materials.MatCount-1].FShininess:= si * 1.28;
              end;
            FLOAT_PERCENTAGE:
              begin
                f.Read(fl, SizeOf(fl));
                Materials[Materials.MatCount-1].FShininess:= fl * 1.28;
              end;
          end;
          ChunkType:= MDATA;
        end;
      MAT_TRANSPARENCY:
        begin
          f.Seek(6, soFromCurrent);
          f.Read(si, SizeOf(si));
          Materials[Materials.MatCount-1].Transparent:= Round(si * 2.55);
          ChunkType:= MDATA;
        end;
      MAT_WIRE:;
//        with glScenes do
//          Materials[MatCount-1].PolygonMode:= GL_LINE;
      MSH_MAT_GROUP:
        begin
          Str:= ReadString(f);
          w:= Readword;
          if w <> 0 then
            begin
              GLObject.FaceGroupCount:= GLObject.FaceGroupCount + 1; //добавить группу
              with GLObject.FaceGroups[GLObject.FaceGroupCount-1] do
                begin
                  Material:= Materials.GetMaterial(Str);   // материал группы
                  FaceCount:= w;                 // кол-во фейсов в группе
// FacesNumber будет содержать номера фейсов, записанных в группах
                  SetLength(FacesNumber, FaceNumberCount + FaceCount);  // расширить FacesNumber
                  f.Read(FacesNumber[FaceNumberCount], Sizeof(word) * FaceCount); //  прочитать
                  OriginFace:= FaceNumberCount;
                  Inc(FaceNumberCount, FaceCount);
                end;
            end;
          ChunkType:= MDATA;
        end;
      MAT_GROUP:     // это уже сохраненные группы
        begin
          GLObject.FaceGroupCount:= GLObject.FaceGroupCount + 1; //добавить группу
          Str:= ReadString(f);
          with GLObject.FaceGroups[GLObject.FaceGroupCount-1] do
             begin
               Material:= Materials.GetMaterial(Str);   // материал группы
               f.Read(OriginFace, SizeOf(OriginFace));
               f.Read(FaceCount, SizeOf(FaceCount));
             end;
        end;
      BackGround:
        begin
          f.Read(Color, SizeOf(Color));
          BG.ClearColor:= Color;
        end;

      MAT_TEXMAP:   Map:= TEX;
      MAT_TEX2MAP:  Map:= TEX2;
      MAT_OPACMAP:  Map:= OPAC;
      MAT_REFLMAP:  Map:= REFL;
      MAT_BUMPMAP:  Map:= BUMP;
      MAT_SPECMAP:  Map:= SPEC;
      MAT_SHINMAP:  Map:= SHIN;
      MAT_SELFIMAP: Map:= SELFI;

      MAT_MAPNAME:
        begin
          if Map = Tex then
            with Materials do
              begin
// здесь идет имя файла текстуры
                TexName:= ReadString(f);
                if GetTexture(TexName) = nil then  // если такой текстуры еще нет
                  begin
                    Materials[MatCount-1].Texture:= NewTexture;
                    Textures[TexCount-1].FileName:= TexName;
                    Textures[TexCount-1].File3dPath:= ExtractFilePath(FName);
                  end else
                  begin
// текстура с таким именем уже есть, назначить ее этому материалу                  
                    Materials[MatCount-1].Texture:= GetTexture(TexName);
                  end;  
              end  else
          ReadString(f);
          ChunkType:= MDATA;
        end;
      Tex_Param:
        begin
          f.Read(TexPar, 1);
          with Materials do
            if Assigned(Textures[TexCount-1]) then
              with Textures[TexCount-1] do
                begin
                  if (TexPar and 1) <> 0 then
                    MinFilter:= GL_NEAREST else MinFilter:= GL_LINEAR;
                  if (TexPar and 2) <> 0 then
                    MagFilter:= GL_NEAREST else MagFilter:= GL_LINEAR;
                  if (TexPar and 4) <> 0 then
                    WrapS:= GL_CLAMP else WrapS:= GL_REPEAT;
                  if (TexPar and 8) <> 0 then
                    WrapT:= GL_CLAMP else WrapT:= GL_REPEAT;
                  if (TexPar and 16) <> 0 then
                    EnvMode:= GL_DECAL else EnvMode:= GL_MODULATE;
                  if (TexPar and 32) <> 0 then
                    EnvMode:= GL_BLEND;
                  f.Read(Transparent, SizeOf(Transparent));                    
                end;
          ChunkType:= MDATA;
        end;

      N_DIRECT_LIGHT:                    // источник света
        begin
          Inc(CurrentLight);
          f.Read(Vector, SizeOf(Vector));
          Lighting.Position[CurrentLight]:= Vector;
          f.Seek(6, soFromCurrent);
          f.Read(ColorF, SizeOf(single) * 3);  ColorF.A:= 1;
          Lighting.Diffuse[CurrentLight]:= ColorFToTColor(ColorF);
          Lighting.Specular[CurrentLight]:= ColorFToTColor(ColorF);
// ambient уменьшаем в 2 раза
  //        ColorF.R:= ColorF.R / 2; ColorF.G:= ColorF.G / 2; ColorF.B:= ColorF.B / 2;
          Lighting.Ambient[CurrentLight]:= clBlack; //ColorFToTColor(ColorF);

          Lighting.Enabled[CurrentLight]:= True;
          ChunkType:= MDATA;
        end;
      DL_SPOTLIGHT:
        begin
          SavePos:= f.Position;
          Lighting.Infinity[CurrentLight]:= False;
          f.Read(Vector, SizeOf(Vector));
          Vector.X:= Vector.X - Lighting.Position[CurrentLight].X;
          Vector.Y:= Vector.Y - Lighting.Position[CurrentLight].Y;
          Vector.Z:= Vector.Z - Lighting.Position[CurrentLight].Z;

          Lighting.Direction[CurrentLight]:= Vector;
          f.Read(fl, SizeOf(fl));
          f.Read(fl, SizeOf(fl));
          Lighting.SpotCutOff[CurrentLight]:= fl;
          f.Position:= SavePos;
        end;
      Model_Ambient:
        begin
          f.Read(Color, SizeOf(Color));
          Lighting.ModelAmbient:= Color;
          f.Read(b, SizeOf(b));
          Lighting.LocalViewer:= b;
          f.Read(b, SizeOf(b));
          Lighting.TwoSide:= b;
        end;
      Light:
        begin
          f.Read(CurrentLight, 1);
          f.Read(glLight, SizeOf(glLight));
          Lighting[CurrentLight]:= glLight;
        end;
      Look_At:
        begin
          f.Read(EyePoint, SizeOf(EyePoint)); f.Read(RefPoint, SizeOf(RefPoint));
          f.Read(UpVector, SizeOf(UpVector));
        end;
      Scene_Perspective:
        begin
          f.Read(fovy, SizeOf(fovy)); f.Read(zNear, SizeOf(zNear));
          f.Read(zFar, SizeOf(zFar)); //f.Read(Aspect, SizeOf(Aspect));
//          f.Read(FAutoAspect, SizeOf(FAutoAspect));
        end;

      AMBIENT_NODE_TAG,
      CAMERA_NODE_TAG,
      TARGET_NODE_TAG,
      LIGHT_NODE_TAG,
      L_TARGET_NODE_TAG,
      SPOTLIGHT_NODE_TAG,
      OBJECT_NODE_TAG:
        begin
          Inc(MotionCount);
          SetLength(Motions, MotionCount);  // завести новую запись
        end;
      NODE_HDR:
        begin
          Str:= ReadString(f);
          f.Seek(SizeOf(word) * 2 , soFromCurrent);
          f.Read(Prnt, SizeOf(Prnt));
            with Motions[MotionCount - 1] do
              begin
                Name:= Str;                         // имя объекта
                Parent:= Prnt;
              end;
          ChunkType:= MDATA;
        end;

      INSTANCE_NAME:
        begin
          Motions[MotionCount - 1].Name:= Motions[MotionCount - 1].Name + '.' +
                                                                ReadString(f);
          ChunkType:= MDATA;
        end;
      PIVOT:
        begin
          with Motions[MotionCount - 1] do
            f.Read(Pivot, SizeOf(Pivot));
          ChunkType:= MDATA;
        end;
      POS_TRACK_TAG:
          with Motions[MotionCount - 1] do
            begin
              f.Seek(SizeOf(word) + 2*SizeOf(cardinal), soFromCurrent);
              f.Read(TransKeyCount, SizeOf(TransKeyCount));
              SetLength(Translation, TransKeyCount);
              for i:= 0 to TransKeyCount - 1 do
                begin
                  f.Read(Translation[i].Frame, SizeOf(Translation[i].Frame));
                  SeekFlags;
                  f.Read(Translation[i].Vector, SizeOf(Translation[i].Vector));
                end;
              ChunkType:= MDATA;
            end;
      ROT_TRACK_TAG:
          with Motions[MotionCount - 1] do
            begin
              f.Seek(SizeOf(word) + 2*SizeOf(cardinal), soFromCurrent);
              f.Read(RotKeyCount, SizeOf(RotKeyCount));
              SetLength(Rotation, RotKeyCount);
              for i:= 0 to RotKeyCount - 1 do
                begin
                  f.Read(Rotation[i].Frame, SizeOf(Rotation[i].Frame));
                  SeekFlags;
                  f.Read(Rotation[i].Angle, SizeOf(Rotation[i].Angle));
                  f.Read(Rotation[i].Vector, SizeOf(TVector));
                end;
              ChunkType:= MDATA;
            end;
      SCL_TRACK_TAG:
          with Motions[MotionCount - 1] do
            begin
              f.Seek(SizeOf(word) + 2*SizeOf(cardinal), soFromCurrent);
              f.Read(ScaleKeyCount, SizeOf(ScaleKeyCount));
              SetLength(Scaling, ScaleKeyCount);
              for i:= 0 to ScaleKeyCount - 1 do
                begin
                  f.Read(Scaling[i].Frame, SizeOf(Scaling[i].Frame));
                  SeekFlags;
                  f.Read(Scaling[i].Vector, SizeOf(Scaling[i].Vector));
                end;
              ChunkType:= MDATA;
            end;
      XDATA_ENTRY:
        begin
          f.Seek(ChunkSize - 6, soFromCurrent);
          ChunkType:= MDATA;
        end;
    end;
    f.Seek(SeekChild(ChunkType, ChunkSize), soFromCurrent);
  end;
  if UpperCase(ExtractFileExt(FName)) = '.3DS' then
    CorrectFaces;

  if Uppercase(ExtractFileExt(FName)) = '.3DS' then
    BuildObjectsMatrix;         // строим матрицу только первый раз, потом используем построенную

  Perspective;
  Lighting.Enabled[0]:= True;

  f.Free;
  finally
    Screen.Cursor:= crDefault;
  end;
end;

procedure TGLScene.BuildObjectsMatrix;

function MatrixDetInternal(a1, a2, a3, b1, b2, b3, c1, c2, c3: Single): Single;

// internal version for the determinant of a 3x3 matrix

begin
  Result := a1 * (b2 * c3 - b3 * c2) -
            b1 * (a2 * c3 - a3 * c2) +
            c1 * (a2 * b3 - a3 * b2);
end;

procedure MatrixAdjoint(var M: TMatrix); register;

// Adjoint of a 4x4 matrix - used in the computation of the inverse
// of a 4x4 matrix

var a1, a2, a3, a4,
    b1, b2, b3, b4,
    c1, c2, c3, c4,
    d1, d2, d3, d4: Single;


begin
    a1 :=  M[0, 0]; b1 :=  M[0, 1];
    c1 :=  M[0, 2]; d1 :=  M[0, 3];
    a2 :=  M[1, 0]; b2 :=  M[1, 1];
    c2 :=  M[1, 2]; d2 :=  M[1, 3];
    a3 :=  M[2, 0]; b3 :=  M[2, 1];
    c3 :=  M[2, 2]; d3 :=  M[2, 3];
    a4 :=  M[3, 0]; b4 :=  M[3, 1];
    c4 :=  M[3, 2]; d4 :=  M[3, 3];

    // ro3 column labeling reversed since 3e transpose ro3s & columns
    M[0, 0] :=  MatrixDetInternal(b2, b3, b4, c2, c3, c4, d2, d3, d4);
    M[1, 0] := -MatrixDetInternal(a2, a3, a4, c2, c3, c4, d2, d3, d4);
    M[2, 0] :=  MatrixDetInternal(a2, a3, a4, b2, b3, b4, d2, d3, d4);
    M[3, 0] := -MatrixDetInternal(a2, a3, a4, b2, b3, b4, c2, c3, c4);

    M[0, 1] := -MatrixDetInternal(b1, b3, b4, c1, c3, c4, d1, d3, d4);
    M[1, 1] :=  MatrixDetInternal(a1, a3, a4, c1, c3, c4, d1, d3, d4);
    M[2, 1] := -MatrixDetInternal(a1, a3, a4, b1, b3, b4, d1, d3, d4);
    M[3, 1] :=  MatrixDetInternal(a1, a3, a4, b1, b3, b4, c1, c3, c4);

    M[0, 2] :=  MatrixDetInternal(b1, b2, b4, c1, c2, c4, d1, d2, d4);
    M[1, 2] := -MatrixDetInternal(a1, a2, a4, c1, c2, c4, d1, d2, d4);
    M[2, 2] :=  MatrixDetInternal(a1, a2, a4, b1, b2, b4, d1, d2, d4);
    M[3, 2] := -MatrixDetInternal(a1, a2, a4, b1, b2, b4, c1, c2, c4);

    M[0, 3] := -MatrixDetInternal(b1, b2, b3, c1, c2, c3, d1, d2, d3);
    M[1, 3] :=  MatrixDetInternal(a1, a2, a3, c1, c2, c3, d1, d2, d3);
    M[2, 3] := -MatrixDetInternal(a1, a2, a3, b1, b2, b3, d1, d2, d3);
    M[3, 3] :=  MatrixDetInternal(a1, a2, a3, b1, b2, b3, c1, c2, c3);
end;

function MatrixDeterminant(M: TMatrix): Single; register;

// Determinant of a 4x4 matrix

var a1, a2, a3, a4,
    b1, b2, b3, b4,
    c1, c2, c3, c4,
    d1, d2, d3, d4  : Single;

begin
  a1 := M[0, 0];  b1 := M[0, 1];  c1 := M[0, 2];  d1 := M[0, 3];
  a2 := M[1, 0];  b2 := M[1, 1];  c2 := M[1, 2];  d2 := M[1, 3];
  a3 := M[2, 0];  b3 := M[2, 1];  c3 := M[2, 2];  d3 := M[2, 3];
  a4 := M[3, 0];  b4 := M[3, 1];  c4 := M[3, 2];  d4 := M[3, 3];

  Result := a1 * MatrixDetInternal(b2, b3, b4, c2, c3, c4, d2, d3, d4) -
            b1 * MatrixDetInternal(a2, a3, a4, c2, c3, c4, d2, d3, d4) +
            c1 * MatrixDetInternal(a2, a3, a4, b2, b3, b4, d2, d3, d4) -
            d1 * MatrixDetInternal(a2, a3, a4, b2, b3, b4, c2, c3, c4);
end;

procedure MatrixScale(var M: TMatrix; Factor: Single); register;

// multiplies all elements of a 4x4 matrix with a factor

var I, J: Integer;

begin
  for I := 0 to 3 do
    for J := 0 to 3 do M[I, J] := M[I, J] * Factor;
end;

procedure MatrixInvert(var M: TMatrix); //register;

// finds the inverse of a 4x4 matrix
var
  Det: Single;
begin
  Det := MatrixDeterminant(M);
  if Abs(Det) < 1E-100 then M := IdentityMatrix
                        else
  begin
    MatrixAdjoint(M);
    MatrixScale(M, 1 / Det);
  end;
end;

function MakeAffineVector(V: array of Single): TVector; assembler;

// creates a vector from given values
// EAX contains address of V
// ECX contains address to result vector
// EDX contains highest index of V

asm
              PUSH EDI
              PUSH ESI
              MOV EDI, ECX
              MOV ESI, EAX
              MOV ECX, EDX
              INC ECX
              CMP ECX, 3
              JB  @@1
              MOV ECX, 3
@@1:          REP MOVSD                     // copy given values
              MOV ECX, 2
              SUB ECX, EDX                   // determine missing entries
              JS  @@Finish
              XOR EAX, EAX
              REP STOSD                     // set remaining fields to 0
@@Finish:     POP ESI
              POP EDI
end;

procedure SinCos(Theta: Extended; var Sin, Cos: Extended); assembler; register;

// calculates sine and cosine from the given angle Theta
// EAX contains address of Sin
// EDX contains address of Cos
// Theta is passed over the stack

asm
              FLD  Theta
              FSINCOS
              FSTP TBYTE PTR [EDX]    // cosine
              FSTP TBYTE PTR [EAX]    // sine
              FWAIT
end;

function CreateRotationMatrix(Axis: TVector; Angle: single): TMatrix; register;

// Creates a rotation matrix along the given Axis by the given Angle in radians.

var cosine,
    sine,
    Len,
    one_minus_cosine: Extended;

begin
  SinCos(Angle, Sine, Cosine);
  one_minus_cosine := 1 - cosine;
  Len := Normalize(Axis);

  if Len = 0 then Result := IdentityMatrix
             else
  begin
    Result[0, 0]:= (one_minus_cosine * Sqr(Axis.X)) + Cosine;
    Result[0, 1]:= (one_minus_cosine * Axis.X * Axis.Y) - (Axis.Z * Sine);
    Result[0, 2]:= (one_minus_cosine * Axis.Z * Axis.X) + (Axis.Y * Sine);
    Result[0, 3]:= 0;

    Result[1, 0]:= (one_minus_cosine * Axis.X * Axis.Y) + (Axis.Z * Sine);
    Result[1, 1]:= (one_minus_cosine * Sqr(Axis.Y)) + Cosine;
    Result[1, 2]:= (one_minus_cosine * Axis.Y * Axis.Z) - (Axis.X * Sine);
    Result[1, 3]:= 0;

    Result[2, 0]:= (one_minus_cosine * Axis.Z * Axis.X) - (Axis.Y * Sine);
    Result[2, 1]:= (one_minus_cosine * Axis.Y * Axis.Z) + (Axis.X * Sine);
    Result[2, 2]:= (one_minus_cosine * Sqr(Axis.Z)) + Cosine;
    Result[2, 3]:= 0;

    Result[3, 0]:= 0;
    Result[3, 1]:= 0;
    Result[3, 2]:= 0;
    Result[3, 3]:= 1;
  end;
end;

function CreateScaleMatrix(V: TVector): TMatrix; register;
// creates scaling matrix
begin
  Result := IdentityMatrix;
  Result[0,0]:= V.X;
  Result[1,1]:= V.Y;
  Result[2,2]:= V.Z;
end;

function MatrixMultiply(M1, M2: TMatrix): TMatrix; register;

// multiplies two 4x4 matrices

var I, J: Integer;
    TM: TMatrix;

begin
  for I := 0 to 3 do
    for J := 0 to 3 do
      TM[I, J] := M1[I, 0] * M2[0, J] +
                  M1[I, 1] * M2[1, J] +
                  M1[I, 2] * M2[2, J] +
                  M1[I, 3] * M2[3, J];
  Result := TM;
end;

function GetMotion(ObjName: string): PMotion;
var
  i: integer;
begin
  Result:= Nil;
  for i:= 0 to MotionCount - 1 do
    if AnsiUpperCase(Motions[i].Name) = AnsiUpperCase(ObjName) then
      begin
        Result:= @Motions[i];
        Exit;
      end;
end;

var
  i: integer;
  Vector: TVector;
  Motion: PMotion;

begin
  for i:= 0 to ObjectCount - 1 do
    with Objects[i] do
      begin
        if MatrixBuilt then
          Continue;
        Motion:= GetMotion(Name);  // взять из Motions
        with Motion^ do
        if (Motion <> nil) and (Motion.Parent > -1) and
        ((ScaleKeyCount > 0) and (Scaling[0].Frame = 0)) and
        ((RotKeyCount > 0) and (Rotation[0].Frame = 0)) and
        ((TransKeyCount > 0) and (Translation[0].Frame = 0)) then
// если в Motions есть такое имя, то:
          begin
// инвертировать матрицу
            MatrixInvert(Matrix);
// вычесть Pivot - центр
            Matrix[3,0]:= Matrix[3, 0] - Motion.Pivot.X;
            Matrix[3,1]:= Matrix[3, 1] - Motion.Pivot.Y;
            Matrix[3,2]:= Matrix[3, 2] - Motion.Pivot.Z;
            repeat
            with Motion^ do
              begin
                              //  scaling
                if (ScaleKeyCount > 0) and (Scaling[0].Frame = 0) then
                  begin
                    Vector:= MakeAffineVector([Scaling[0].Vector.X,
                                 Scaling[0].Vector.Y, Scaling[0].Vector.Z]);
                    Matrix := MatrixMultiply(Matrix, CreateScaleMatrix(Scaling[0].Vector));
                  end;
                             // rotation
                if (RotKeyCount > 0) and (Rotation[0].Frame = 0) then
                  begin
                    Vector:= MakeAffineVector([Rotation[0].Vector.X,
                                 Rotation[0].Vector.Y, Rotation[0].Vector.Z]);
                    Matrix := MatrixMultiply(Matrix, CreateRotationMatrix(Vector, Rotation[0].Angle));
                  end;
                             // translation
                if (TransKeyCount > 0) and (Translation[0].Frame = 0) then
                  begin
                    Matrix[3,0]:= Matrix[3, 0] + Translation[0].Vector.X;
                    Matrix[3,1]:= Matrix[3, 1] + Translation[0].Vector.Y;
                    Matrix[3,2]:= Matrix[3, 2] + Translation[0].Vector.Z;
                  end;
              end;
              if Motion.Parent = -1 then
                Break;
              Motion:= @Motions[Motion.Parent];     // взять предка
            until False;
          end else
          Matrix:= IdentityMatrix;
        MatrixBuilt:= True;
      end;
end;

{procedure TGLScene.SetPolygonMode(APolygonMode: GLenum);
begin
  if FPolygonMode = APolygonMode then
    Exit;
  FPolygonMode:= APolygonMode;
  glPolygonMode(GL_FRONT_AND_BACK, APolygonMode);
end; }

procedure TGLScene.SetAutoAspect(AAutoAspect: boolean);
begin
  if FAutoAspect = AAutoAspect then
    Exit;
  FAutoAspect:= AAutoAspect;
  ReSize;
end;                                                

procedure TGLScene.Perspective;
var
  d1,d2,d3,d4: double;
begin
  d1:= fovy; d2:= Aspect; d3:= zNear; d4:= zFar;
  glMatrixMode(GL_PROJECTION);
  glLoadIdentity;
  gluPerspective(d1, d2, d3, d4);
  glMatrixMode(GL_MODELVIEW);
end;

function TGLScene.GetObjectFromScreenCoord(X,Y: integer): TGLObject;
var
  FeedBackBuf: array of single;  // массив для FeedBack буфера
  FeedBackBufSize: integer;
  sz: integer;
  i: integer;
  MinZ, CurMinZ: single;
  Res: single;
  FaceNum: integer;
  SaveJitter: boolean;

procedure GetMemFeedBack;
var
  i: integer;
begin
  FeedBackBufSize:= 0;
  for i:= 0 to ObjectCount - 1 do
    case Objects[i].PolygonMode of
// если fill, то на каждый полигон идет GL_POLYGON_TOKEN, затем кол-во точек в полигоне -
// всегда тройка и 9 координат, по 3 на каждую вершину - итого 11
      GL_FILL: FeedBackBufSize:= FeedBackBufSize + Objects[i].FaceCount * 11;

// при line идет GL_LINE_RESET_TOKEN, затем 6 координат первого отрезка,
// потом 2 раза GL_LINE_TOKEN и снова 6 координат следующего отрезка - итого 21
      GL_LINE: FeedBackBufSize:= FeedBackBufSize + Objects[i].FaceCount * 21;

// при point идет GL_POINT_TOKEN и 3 координаты на каждую грань - итого 12
      GL_POINT: FeedBackBufSize:= FeedBackBufSize + Objects[i].FaceCount * 12;
    end;
  Inc(FeedBackBufSize, 2 * ObjectCount);
  SetLength(FeedBackBuf, FeedBackBufSize);
end;

begin
  GetMemFeedBack;
  repeat
    glFeedBackBuffer(FeedBackBufSize, GL_3D, @FeedBackBuf[0]);
    RenderMode:= GL_FEEDBACK;
    SaveJitter:= Jitter.Enabled;
    Jitter.Enabled:= False;        //  отключить сглаживание, иначе будет очень долго
    Draw;
    Jitter.Enabled:= SaveJitter;
    sz:= glRenderMode(GL_RENDER);
    if sz = -1 then
      begin
        FeedBackBufSize:= FeedBackBufSize + 100000;
        SetLength(FeedBackBuf, FeedBackBufSize);
      end;
  until sz <> -1;
{  if sz = -1 then
    begin
      FeedBackBufSize:= 0;
      SetLength(FeedBackBuf, FeedBackBufSize);
      ShowMessage('FeedBack BufferSize wrong.');
    end;}
  Y:= Screen.ClientHeight - Y;
  MinZ:= MaxInt;
  Res:= 0;
  Result:= Nil;
  i:= 0;
  while i < sz do
    begin
      if FeedBackBuf[i] = GL_POLYGON_TOKEN then
        begin
          Inc(FaceNum);
          if PointInTriangles(@FeedBackBuf[i+2], X, Y) then
            begin
             // берем среднее значение координаты z для грани
              CurMinZ:= (FeedBackBuf[i+4] + FeedBackBuf[i+7] + FeedBackBuf[i+10])/3;
              if CurMinZ < MinZ then
                begin
                  MinZ:= CurMinZ;
                  Result:= TglObject(Res);
                  ObjectFaceNumber:= FaceNum;
                end;
            end;
          Inc(i, 10);
        end else
        // объект нарисован линиями
        if FeedBackBuf[i] = GL_LINE_RESET_TOKEN then
        begin
   //       Inc(ObjectFaceNumber);
          Move(FeedBackBuf[i+11], FeedBackBuf[i+7], 3*SizeOf(single));
          if PointInTriangles(@FeedBackBuf[i+1], X, Y) then
            begin
              CurMinZ:= (FeedBackBuf[i+3] + FeedBackBuf[i+6] + FeedBackBuf[i+9])/3;
              if CurMinZ < MinZ then
                begin
                  // берем среднее значение координаты z для грани
                  MinZ:= (FeedBackBuf[i+3] + FeedBackBuf[i+6] + FeedBackBuf[i+9])/3;
                  Result:= TglObject(Res);
                end;
            end;
          Inc(i, 20);
        end else
        // объект нарисован точками
        if FeedBackBuf[i] = GL_POINT_TOKEN then
        begin
     //     Inc(ObjectFaceNumber);
          Move(FeedBackBuf[i+5], FeedBackBuf[i+4], 3*SizeOf(single));
          Move(FeedBackBuf[i+9], FeedBackBuf[i+7], 3*SizeOf(single));
          if PointInTriangles(@FeedBackBuf[i+1], X, Y) then
            begin
              CurMinZ:= (FeedBackBuf[i+3] + FeedBackBuf[i+6] + FeedBackBuf[i+9])/3;
              if CurMinZ < MinZ then
                begin
                  // берем среднее значение координаты z для грани
                  MinZ:= (FeedBackBuf[i+3] + FeedBackBuf[i+6] + FeedBackBuf[i+9])/3;
                  Result:= TglObject(Res);
                end;
            end;
          Inc(i, 11);
        end else
        // указатель на объект, который мы сами записали
        if FeedBackBuf[i] = GL_PASS_THROUGH_TOKEN then
          begin
            Res:= FeedBackBuf[i+1];
            FaceNum:= -1;
          end;
      Inc(i);
    end;
  SetLength(FeedBackBuf, 0);
end;

{procedure TGLScene.SetBGFileName(ABGFileName: string);
begin
  FBGFileName:= ExtractFileName(ABGFileName);
  if FBGFileName = '' then
    begin
      if Assigned(BGTexture) then
        BGTexture.Free;
      BGTexture:= Nil;
      Exit;
    end;
  if not FileExists(FBGFileName) then
    BGFileName:= '';

  if Assigned(BGTexture) then
    BGTexture.Free;
  BGTexture:= TTexture.Create;
  BGTexture.FileName:= BGFileName;
  BGTexture.EnvMode:= GL_DECAL;
end;  }

procedure TGLScene.FogSave(f: TFileStream);
var
  b: boolean;
  p: single;
  ColorF: TColorF;
  C: TColor;
begin
  b:= glIsEnabled(GL_FOG);
  f.Write(b, SizeOf(b));
  glGetFloatv(GL_FOG_MODE, @p);
  f.Write(p, SizeOf(p));
  glGetFloatv(GL_FOG_DENSITY, @p);
  f.Write(p, SizeOf(p));
  glGetFloatv(GL_FOG_START, @p);
  f.Write(p, SizeOf(p));
  glGetFloatv(GL_FOG_END, @p);
  f.Write(p, SizeOf(p));
  glGetFloatv(GL_FOG_COLOR, @ColorF);
  C:= ColorFToTColor(ColorF);
  f.Write(C, SizeOf(C));
//  glGetFloatv(GL_FOG_Hint, @p);
//  f.Write(p, SizeOf(p));
end;

procedure TglScene.FogRead(f: TFileStream);
var
  b: boolean;
  p: GLfloat;
  ColorF: TColorF;
begin
  f.Read(b, SizeOf(b));
  if b then
    glEnable(GL_FOG) else
    glDisable(GL_FOG);
  f.Read(p, SizeOf(p));
  glFog(GL_FOG_MODE, p);
  f.Read(p, SizeOf(p));
  glFog(GL_FOG_DENSITY, p);
  f.Read(p, SizeOf(p));
  glFog(GL_FOG_START, p);
  f.Read(p, SizeOf(p));
  glFog(GL_FOG_END, p);
  f.Read(ColorF, SizeOf(ColorF));
  glFogfv(GL_FOG_COLOR, @ColorF);
//  f.Read(p, SizeOf(p));
//  glHint(GL_FOG_HINT, Round(p));
end;

{function GetglSObject: TglObject;
begin
  Result:= TglObject.Create;
end; }

function TglScene.NewObject: TglObject;
begin
  Result:= glObject;
  AddObject(Result);
end;

function TglScene.GetObject(ObjectName: string): TglObject;
var
  i: integer;
begin
  Result:= Nil;
  for i:= 0 to ObjectCount - 1 do
    if AnsiUpperCase(Objects[i].Name) = AnsiUpperCase(ObjectName) then
      begin
        Result:= Objects[i];
        Exit;
      end;
end;

procedure TglScene.LightingSaveToFile(f: TFileStream);
var
  glLight: TLight;
  i: integer;
  MA: TColor;
  b: boolean;
  pos,pos1: cardinal;
  w: word;
begin
  MA:= Lighting.ModelAmbient;
  f.Write(MA, SizeOf(MA));      // ModelAmbient

  b:= Lighting.LocalViewer;    //  LocalViewer
  f.Write(b, SizeOf(b));

  b:= Lighting.TwoSide;
  f.Write(b, SizeOf(b));       // TwoSide

//  f.Write(w, SizeOf(w));       // reserve

  pos:= f.Position;
  f.Seek(SizeOf(cardinal), soFromCurrent);  // оставить место для окончания записи источников света
  for i:= 0 to MaxLights - 1 do
    begin
      glLight:= Lighting[i];
      if CompareMem(@glLight, @DefaultLight, SizeOf(TLight)) then
        Continue;
      f.Write(byte(i), 1);
      f.Write(glLight, SizeOf(glLight));
 //     f.Write(w, SizeOf(w));       // reserve
    end;
  pos1:= f.Position;
  f.Position:= pos;
  f.Write(pos1, SizeOf(pos1));
  f.Position:= pos1;               // вернуться
end;

procedure TglScene.LightingReadFromFile(f: TFileStream);
var
  MA: TColor;
  b: boolean;
  pos: cardinal;
  glLight: TLight;
  LightNum: byte;
begin
  f.Read(MA, SizeOf(MA));      // ModelAmbient
  Lighting.ModelAmbient:= MA;
  f.Read(b, SizeOf(b));
  Lighting.LocalViewer:= b;;    //  LocalViewer
  f.Read(b, SizeOf(b));       // TwoSide
  Lighting.TwoSide:= b;
//  f.Seek(2, soFromCurrent);       // reserve

  f.Read(pos, SizeOf(pos));
  while f.Position < pos do
    begin
      f.Read(LightNum, 1);             // номер источника
      f.Read(glLight, SizeOf(glLight));
      Lighting[LightNum]:= glLight;
//      f.Seek(2, soFromCurrent);       // reserve
    end;
end;

function TglScene.PixelsPerUnit: single;
var
  Vector1, Vector2: TVector;
  modM, prM: array[0..15] of double;
  Viewport: array[0..3] of integer;
  x1,x2,y1,y2,z1,z2: double;
begin
  Vector1:= Vector(0,0,0); Vector2:= Vector(20, 20, 20);
  glGetDoublev(GL_MODELVIEW_MATRIX, @modM);
  glGetDoublev(GL_PROJECTION_MATRIX, @prM);
  glGetIntegerv(GL_VIEWPORT, @Viewport);
// получить в x1,y1,z1 оконные координаты начала координат сцены
  gluProject(Vector1.X, Vector1.Y, Vector1.Z, @modM, @prM, @Viewport, x1, y1, z1);
// получить в x2,y2,z2 оконные координаты при смещении на Vector2 - Vector1 юнитов
  gluProject(Vector2.X, Vector2.Y, Vector2.Z, @modM, @prM, @Viewport, x2, y2, z2);
  Result:= VectorDistance(Vector(x1, y1, z1), Vector(x2, y2, z2)) / VectorDistance(Vector1, Vector2);
end;

procedure TglScene.LightsOff;
var
  i: integer;
begin
  for i:= 0 to MaxLights - 1 do
    Lighting.Enabled[i]:= False;
end;


// ===================== TGLLighting =========================================

class function TLighting.GetAmbient(Index: integer): TColor;
var
  CF: TColorF;
begin
  glGetLightfv(GL_LIGHT0 + Index, GL_AMBIENT, @CF);
  Result:= ColorFToTColor(CF);
end;

class procedure TLighting.SetAmbient(Index: integer; AAmbient: TColor);
var
  CF: TColorF;
begin
  CF:= ColorToColorF(AAmbient, 1);
  glLightfv(GL_LIGHT0 + Index, GL_AMBIENT, @CF);
end;

class function TLighting.GetDiffuse(Index: integer): TColor;
var
  CF: TColorF;
begin
  glGetLightfv(GL_LIGHT0 + Index, GL_DIFFUSE, @CF);
  Result:= ColorFToTColor(CF);
end;

class procedure TLighting.SetDiffuse(Index: integer; ADiffuse: TColor);
var
  CF: TColorF;
begin
  CF:= ColorToColorF(ADiffuse, 1);
  glLightfv(GL_LIGHT0 + Index, GL_DIFFUSE, @CF);
end;

class function TLighting.GetSpecular(Index: integer): TColor;
var
  CF: TColorF;
begin
  glGetLightfv(GL_LIGHT0 + Index, GL_SPECULAR, @CF);
  Result:= ColorFToTColor(CF);
end;

class procedure TLighting.SetSpecular(Index: integer; ASpecular: TColor);
var
  CF: TColorF;
begin
  CF:= ColorToColorF(ASpecular, 1);
  glLightfv(GL_LIGHT0 + Index, GL_SPECULAR, @CF);
end;

class function TLighting.GetPosition(Index: integer): TVector;
var
  VW: TVectorW;
begin
  glGetLightfv(GL_LIGHT0 + Index, GL_POSITION, @VW);
  Result:= VW.Vector;
end;

class procedure TLighting.SetPosition(Index: integer; APosition: TVector);
var
  VW: TVectorW;
begin
  glGetLightfv(GL_LIGHT0 + Index, GL_POSITION, @VW);
  VW.Vector:= APosition;
  VW.W:= ord(not GetInfinity(Index));
  glPushMatrix;
  glLoadIdentity;
  glLightfv(GL_LIGHT0 + Index, GL_POSITION, @VW);
  glPopMatrix;
end;

class function TLighting.GetDirection(Index: integer): TVector;
var
  VW: TVectorW;
begin
  glGetLightfv(GL_LIGHT0 + Index, GL_SPOT_DIRECTION, @VW);
  Result:= VW.Vector;
end;

class procedure TLighting.SetDirection(Index: integer; ADirection: TVector);
{var
  VW: TVectorW;}
begin
{  VW.Vector:= ADirection;
  VW.W:= 0; }
  glPushMatrix;
  glLoadIdentity;
  glLightfv(GL_LIGHT0 + Index, GL_SPOT_DIRECTION, @ADirection{VW});
  glPopMatrix;
end;

class function TLighting.GetInfinity(Index: integer): boolean;
var
  VW: TVectorW;
begin
  glGetLightfv(GL_LIGHT0 + Index, GL_POSITION, @VW);
  Result:= VW.W = 0;
end;

class procedure TLighting.SetInfinity(Index: integer; AInfinity: boolean);
var
  VW: TVectorW;
begin
  glGetLightfv(GL_LIGHT0 + Index, GL_POSITION, @VW);
  VW.W:= ord(not AInfinity);
  glPushMatrix;
  glLoadIdentity;
  glLightfv(GL_LIGHT0 + Index, GL_POSITION, @VW);
  glPopMatrix;
end;

class function TLighting.GetAttConst(Index: integer): single;
begin
  glGetLightfv(GL_LIGHT0 + Index, GL_CONSTANT_ATTENUATION, @Result);
end;

class procedure TLighting.SetAttConst(Index: integer; AAttConst: single);
begin
  glLightfv(GL_LIGHT0 + Index, GL_CONSTANT_ATTENUATION, @AAttConst);
end;

class function TLighting.GetAttLinear(Index: integer): single;
begin
  glGetLightfv(GL_LIGHT0 + Index, GL_LINEAR_ATTENUATION, @Result);
end;

class procedure TLighting.SetAttLinear(Index: integer; AAttLinear: single);
begin
  glLightfv(GL_LIGHT0 + Index, GL_LINEAR_ATTENUATION, @AAttLinear);
end;

class function TLighting.GetAttQuad(Index: integer): single;
begin
  glGetLightfv(GL_LIGHT0 + Index, GL_QUADRATIC_ATTENUATION, @Result);
end;

class procedure TLighting.SetAttQuad(Index: integer; AAttQuad: single);
begin
  glLightfv(GL_LIGHT0 + Index, GL_QUADRATIC_ATTENUATION, @AAttQuad);
end;

class function TLighting.GetExponent(Index: integer): single;
begin
  glGetLightfv(GL_LIGHT0 + Index, GL_SPOT_EXPONENT, @Result);
end;

class procedure TLighting.SetExponent(Index: integer; AExponent: single);
begin
  glLightfv(GL_LIGHT0 + Index, GL_SPOT_EXPONENT, @AExponent);
end;

class function TLighting.GetCutOff(Index: integer): single;
begin
  glGetLightfv(GL_LIGHT0 + Index, GL_SPOT_CUTOFF, @Result);
end;

class procedure TLighting.SetCutOff(Index: integer; ACutOff: single);
begin
  glLightfv(GL_LIGHT0 + Index, GL_SPOT_CUTOFF, @ACutOff);
end;

class function TLighting.GetEnabled(Index: integer): boolean;
begin
  Result:= glIsEnabled(GL_LIGHT0 + Index);
end;

class procedure TLighting.SetEnabled(Index: integer; AEnabled: boolean);
begin
  if AEnabled then
    begin
      glEnable(GL_LIGHTING);
      glEnable(GL_LIGHT0 + Index)
    end else
    glDisable(GL_LIGHT0 + Index);
end;

class function TLighting.GetLocalViewer: boolean;
begin
  glGetbooleanv(GL_LIGHT_MODEL_LOCAL_VIEWER, @Result);
end;

class procedure TLighting.SetLocalViewer(ALocalViewer: boolean);
begin
  glLightModelf(GL_LIGHT_MODEL_LOCAL_VIEWER, integer(ALocalViewer));
end;

class function TLighting.GetTwoSide: boolean;
begin
  glGetbooleanv(GL_LIGHT_MODEL_TWO_SIDE, @Result);
end;

class procedure TLighting.SetTwoSide(ATwoSide: boolean);
begin
  glLightModelf(GL_LIGHT_MODEL_TWO_SIDE, integer(ATwoSide));
end;

class function TLighting.GetModelAmbient: TColor;
var
  CF: TColorF;
begin
  glGetFloatv(GL_LIGHT_MODEL_AMBIENT, @CF);
  Result:= ColorFToTColor(CF);
end;

class procedure TLighting.SetModelAmbient(AModelAmbient: TColor);
var
  CF: TColorF;
begin
  CF:= ColorToColorF(AModelAmbient, 1);
  glLightModelfv(GL_LIGHT_MODEL_AMBIENT, @CF);
end;

class function TLighting.GetLight(Index: integer): TLight;
begin
  Result.Ambient:= GetAmbient(Index); Result.Diffuse:= GetDiffuse(Index);
  Result.Specular:= GetSpecular(Index); Result.Position:= GetPosition(Index);
  Result.Infinity:= GetInfinity(Index); Result.Direction:= GetDirection(Index);
  Result.Enabled:= GetEnabled(Index); Result.Exponent:= GetExponent(Index);
  Result.CutOff:= GetCutOff(Index); Result.AttConst:= GetAttConst(Index);
  Result.AttLinear:= GetAttLinear(Index); Result.AttQuad:= GetAttQuad(Index);
end;

class procedure TLighting.SetLight(Index: integer; Light: TLight);
begin
  SetAmbient(Index, Light.Ambient); SetDiffuse(Index, Light.Diffuse);
  SetSpecular(Index, Light.Specular); SetPosition(Index, Light.Position);
  SetInfinity(Index, Light.Infinity); SetDirection(Index, Light.Direction);
  SetEnabled(Index, Light.Enabled); SetExponent(Index, Light.Exponent);
  SetCutOff(Index, Light.CutOff); SetAttConst(Index, Light.AttConst);
  SetAttLinear(Index, Light.AttLinear); SetAttQuad(Index, Light.AttQuad);
end;

// ======================= TglTexts ===========================================

constructor TglTexts.Create;
begin
  inherited;
  FFontCount:= 0;
  FTextCount:= 0;
  FontFormat:= WGL_FONT_POLYGONS;
  Extrusion:= 0.3;
end;

function TglTexts.AddFont(aDC: hDC; Font: TFont): boolean;
var
  FirstListNumber: DWord;
  aFont: hFont;
begin
  Result:= False;
  FirstListNumber:= glGenLists(256);
//  еще влияет на вид шрифта третий параметр
  aFont:= CreateFont(Font.Height, 0, 0, 0, 0{FW_BOLD}, cardinal(fsItalic in Font.Style),
     0, 0, Font.Charset, OUT_TT_PRECIS, CLIP_DEFAULT_PRECIS, ANTIALIASED_QUALITY,
                              FF_DONTCARE or DEFAULT_PITCH, Pchar(Font.Name));
  if aFont = 0 then
    Exit;
  if SelectObject(aDC, aFont) = 0 then
    begin
      DeleteObject(aFont);
      Exit;
    end;
  if not wglUseFontOutlines(aDC, 0, 256, FirstListNumber, 0, Extrusion, FontFormat, nil) then
    Exit;

  DeleteObject(aFont);

  Inc(FFontCount);
  SetLength(OriginList, FFontCount);
  OriginList[FFontCount-1]:= FirstListNumber;
  Result:= True;
end;

procedure TglTexts.DeleteFont(index: word);
var
  i: integer;
begin
  if index >= FontCount then
    Exit;
  glDeleteLists(OriginList[index], 256);
  Move(OriginList[index+1], OriginList[index], SizeOf(DWord) * (FontCount - index - 1));
  Dec(FFontCount);
  SetLength(OriginList, FontCount);
  for i:= 0 to TextCount - 1 do
    if Texts[i].FontNumber = index then
      Texts[i].FontNumber:= -1;

end;

function TglTexts.AddText(aText: string): TglText;
begin
  Result:= TglText.Create(aText);
  if FontCount <> 0 then
    Result.FontNumber:= FontCount - 1;  // назначаем последний созданный или -1
  Inc(FTextCount);
  SetLength(Texts, FTextCount);
  Texts[FTextCount-1]:= Result;
end;

procedure TglTexts.Draw;
var
  i: integer;
begin
  for i:= 0 to TextCount - 1 do
    if Texts[i].FontNumber = -1 then
      Continue else
      begin
        glPushMatrix;
        glPushAttrib(GL_ALL_ATTRIB_BITS);

        if Texts[i].UpFront then
          glDepthFunc(GL_ALWAYS);
        if Assigned(Texts[i].Material) then
          Texts[i].Material.Apply else
          DefaultMaterial.Apply;
        if Assigned(Texts[i].Material) and Assigned(Texts[i].Material.Texture) then
          begin
            glEnable(GL_TEXTURE_GEN_S);
            glEnable(GL_TEXTURE_GEN_T);
            glTexGeni(GL_S, GL_TEXTURE_GEN_MODE, GL_OBJECT_LINEAR);
            glTexGeni(GL_T, GL_TEXTURE_GEN_MODE, GL_OBJECT_LINEAR);

 //   glTexGeni(GL_S, GL_TEXTURE_GEN_MODE, GL_EYE_LINEAR);
 //   glTexGeni(GL_T, GL_TEXTURE_GEN_MODE, GL_EYE_LINEAR);
 //   glTexGeni(GL_S, GL_TEXTURE_GEN_MODE, GL_SPHERE_MAP);
 //   glTexGeni(GL_T, GL_TEXTURE_GEN_MODE, GL_SPHERE_MAP);

            Texts[i].Material.Texture.Apply;
          end;


        glListBase(OriginList[Texts[i].FontNumber]);
        glTranslate(Texts[i].Translate.X, Texts[i].Translate.Y, Texts[i].Translate.Z);
        glRotatef(Texts[i].Rotate.X, 1, 0, 0);
        glRotatef(Texts[i].Rotate.Y, 0, 1, 0);
        glRotatef(Texts[i].Rotate.Z, 0, 0, 1);
        glScalef(Texts[i].Scale.X, Texts[i].Scale.Y, Texts[i].Scale.Z);
        glCallLists(Length(Texts[i].Text), GL_UNSIGNED_BYTE, PChar(Texts[i].Text));
        glPopAttrib;
        glPopMatrix;
      end;
end;

// ============================== TglText ===================================

constructor TglText.Create(aText: string);
begin
  inherited Create;
  Text:= aText;
  FontNumber:= -1;
  Translate:= NullVector;
  Rotate:= NullVector;
  Scale:= Vector(1, 1, 1);
  Frozen:= False;
  UpFront:= False;
  Material:= Nil;
end;

var
  s,s1: string;
  p: integer;

initialization
  Saved8087CW:= Default8087CW;
  Set8087CW($133F);
  ForceCurrentDirectory:= True;
  DecimalSeparator:= '.';
  DefaultMaterial:= TMaterial.Create;
  DefaultMaterial.Name:= 'DEFAULT';
  TPicture.UnregisterGraphicClass(TIcon);
  TPicture.UnregisterGraphicClass(TMetafile);
  s:= GraphicFilter(TGraphic);
  SupportedExt:= TStringList.Create;
  JitterC:= [2,3,4,8,15,24,66];
  repeat
    p:= Pos('*', s);
    Inc(p);
    s1:= '';
    repeat
      s1:= s1 + s[p];
      Inc(p);
    until (s[p] = ';') or (s[p] = ')');
    SupportedExt.Add(UpperCase(s1));
    if s[p] = ')' then
      Break;
    Delete(s, 1, p);
  until false;

finalization
  if Assigned(DefaultMaterial) then
    DefaultMaterial.Free;
  SupportedExt.Free;
  Set8087CW(Saved8087CW);

// SWIMPOOL.3DS - ball

end.



