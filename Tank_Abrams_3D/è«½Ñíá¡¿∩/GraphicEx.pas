unit GraphicEx;

// GraphicEx -
//   This unit is an extension of Graphics.pas, in order to
//   import other graphic files than the those Delphi allows.
//   Currently supported are JPG, GIF, PCX and TGA files by using NViewLib.DLL as well as
//   SGI *.bw and *.rgb images and Autodesk *.pic and *.cel files.
//   Additionally, there are some support routines to stretch images.
//
// Version     - 2.2
// last change : 03. October 1999
//
// (c) Copyright 1999, Dipl. Ing. Mike Lischke (public@lischke-online.de)

{$R-}

interface

uses Windows, Classes, ExtCtrls, {Geometry,} Graphics, SysUtils;

type

  PCardinalVector = ^TCardinalVector;
  TCardinalVector = array[0..0] of Cardinal;

  TExtraGraphic = class(TBitmap)
  public
    procedure LoadFromFile(const FileName: String); override;
  end;

  TSGIGraphic = class(TBitmap)
  private
    FStartPosition: Cardinal;
    FRowStart,
    FRowSize: PCardinalVector;   // actually start and length of a line
    FRowBuffer: Pointer;        // buffer to hold one line while loading
    FImageType: Word;
    function InitStructures(Stream: TStream): Cardinal;
    procedure GetRow(Stream: TStream; Buffer: Pointer; Line, Component: Cardinal);
  public
    procedure LoadFromFile(const FileName: string); override;
    procedure LoadFromStream(Stream: TStream); override;
  end;

  TAutodeskGraphic = class(TBitmap)
  public
    procedure LoadFromFile(const FileName: string); override;
    procedure LoadFromStream(Stream: TStream); override;
  end;

  TResamplingFilter = (sfBox, sfTriangle, sfHermite, sfBell, sfSpline, sfLanczos3, sfMitchell);

// Resampling support routines
{$IFDEF VER100}
procedure Stretch1(NewWidth, NewHeight: Cardinal; Filter: TResamplingFilter; Radius: Single; Source, Target: TBitmap);
procedure Stretch2(NewWidth, NewHeight: Cardinal; Filter: TResamplingFilter; Radius: Single; Source: TBitmap);
{$ELSE}
procedure Stretch(NewWidth, NewHeight: Cardinal; Filter: TResamplingFilter; Radius: Single; Source, Target: TBitmap); overload;
procedure Stretch(NewWidth, NewHeight: Cardinal; Filter: TResamplingFilter; Radius: Single; Source: TBitmap); overload;
{$ENDIF}

var NVLibLoaded: Boolean;

//----------------------------------------------------------------------------------------------------------------------

implementation

uses Consts, Dialogs, Math;

const
  NVLibrary = 'NViewLib.dll';

{$IFDEF VER100}
procedure SetALength(var P : Pointer; iCnt,iSize : Integer);
begin
  ReallocMem(P, iCnt*iSize);
  if iCnt*iSize = 0 then P := nil
  else FillChar(P^, iCnt*iSize, 0);
end;
{$ENDIF}


type
  TRGBInt = record
   R, G, B: Integer;
  end;

  PRGB = ^TRGB;
  TRGB = packed record
   B, G, R: Byte;
  end;

  PPixelArray = ^TPixelArray;
  TPixelArray = array[0..0] of TRGB;

  TFilterFunction = function(Value: Single): Single;

  // contributor for a Pixel
  PContributor = ^TContributor;
  TContributor = record
   Weight: Integer; // Pixel Weight (must be at first place for faster tests)
   Pixel: Integer; // Source Pixel
  end;

{$IFDEF VER100}
  PContributors = ^TContributors;
  TContributors = array[0..0] of TContributor;
{$ELSE}
  TContributors = array of TContributor;
{$ENDIF}

  // list of source pixels contributing to a destination Pixel
{$IFDEF VER100}
  TContributorEntry = record
   N: Integer;
   Contributors: PContributors;
  end;

  PContributorList = ^TContributorList;
  TContributorList = array[0..0] of TContributorEntry;
{$ELSE}
  TContributorEntry = record
   N: Integer;
   Contributors: TContributors;
  end;

  TContributorList = array of TContributorEntry;
{$ENDIF}

{$IFDEF VER100}
  PIntArray = ^TIntArray;
  TIntArray = array[0..0] of integer;
{$ENDIF}

const DefaultFilterRadius: array[TResamplingFilter] of Single =
        (0.5, 1, 1, 1.5, 2, 3, 2);

var // globally used chache for current image (speeds up resampling about 10%)
{$IFDEF VER100}
    CurrentLineR: PIntArray;
    CurrentLineG: PIntArray;
    CurrentLineB: PIntArray;
{$ELSE}
    CurrentLineR: array of Integer;
    CurrentLineG: array of Integer;
    CurrentLineB: array of Integer;
{$ENDIF}

    NViewLibSetLanguage: function(Lang: PChar): Bool; stdcall;
    NViewLibLoad: function(FileName: PChar; ShowProgress: Boolean): HBitmap; stdcall;
    NVLibHandle: THandle;

//----------------- helper functions -------------------------------------------------------------------------

function IntToByte(Value: Integer): Byte;

begin
  if Value < 0 then Result:= 0
               else
    if Value > 255 then Result := 255
                   else Result := Value;
end;

//----------------- filter functions for stretching ----------------------------------------------------------

function HermiteFilter(Value: Single): Single;

// f(t) = 2|t|^3 - 3|t|^2 + 1, -1 <= t <= 1

begin
  if Value < 0 then Value := -Value;
  if Value < 1 then Result := (2 * Value - 3) * Sqr(Value) + 1
               else Result := 0;
end;

//------------------------------------------------------------------------------------------------------------

function BoxFilter(Value: Single): Single;

// This filter is also known as 'nearest neighbour' Filter. It needs some workover though, as the results aren't
// really impressive.

begin
  if (Value > -0.5) and (Value <= 0.5) then Result := 1
                                       else Result := 0;
end;

//------------------------------------------------------------------------------------------------------------

function TriangleFilter(Value: Single): Single;

// aka 'linear' or 'bilinear' filter

begin
  if Value < 0 then Value := -Value;
  if Value < 1 then Result := 1 - Value
               else Result := 0;
end;

//------------------------------------------------------------------------------------------------------------

function BellFilter(Value: Single): Single;

begin
  if Value < 0 then Value := -Value;
  if Value < 0.5 then Result := 0.75 - Sqr(Value)
                 else
    if Value < 1.5 then
    begin
      Value := Value - 1.5;
      Result := 0.5 * Sqr(Value);
    end
    else Result := 0;
end;

//------------------------------------------------------------------------------------------------------------

function SplineFilter(Value: Single): Single;

// B-spline filter

var Temp: Single;

begin
  if Value < 0 then Value := -Value;
  if Value < 1 then
  begin
    Temp := Sqr(Value);
    Result := 0.5 * Temp * Value - Temp + 2 / 3;
  end
  else
    if Value < 2 then
    begin
      Value := 2 - Value;
      Result := Sqr(Value) * Value / 6;
    end
    else Result := 0;
end;

//------------------------------------------------------------------------------------------------------------

function Lanczos3Filter(Value: Single): Single;

  function SinC(Value: Single): Single;

  begin
    if Value <> 0 then
    begin
      Value := Value * Pi;
      Result := Sin(Value) / Value;
    end
    else Result := 1;
  end;
  
begin
  if Value < 0 then Value := -Value;
  if Value < 3 then Result := SinC(Value) * SinC(Value / 3)
               else Result := 0;
end;

//------------------------------------------------------------------------------------------------------------

function MitchellFilter(Value: Single): Single;

const B = 1/3;
      C = 1/3;

var Temp: Single;

begin
  if Value < 0 then Value := -Value;
  Temp := Sqr(Value);
  if Value < 1 then
  begin
    Value := (((12 - 9 * B - 6 * C) * (Value * Temp))
             + ((-18 + 12 * B + 6 * C) * Temp)
             + (6 - 2 * B));
    Result := Value / 6;
  end
  else
    if Value < 2 then
    begin
      Value := (((-B - 6 * C) * (Value * Temp))
               + ((6 * B + 30 * C) * Temp)
               + ((-12 * B - 48 * C) * Value)
               + (8 * B + 24 * C));
      Result := Value / 6;
    end
    else Result := 0;
end;

//------------------------------------------------------------------------------------------------------------

const FilterList: array[TResamplingFilter] of TFilterFunction =
        (BoxFilter,
         TriangleFilter,
         HermiteFilter,
         BellFilter,
         SplineFilter,
         Lanczos3Filter,
         MitchellFilter);

//------------------------------------------------------------------------------------------------------------

procedure FillLineChache(N, Delta: Integer; Line: Pointer);

var I: Integer;
    Run: PRGB;

begin
  Run := Line;
  for I := 0 to N - 1 do
  begin
    CurrentLineR[I] := Run.R;
    CurrentLineG[I] := Run.G;
    CurrentLineB[I] := Run.B;
    Inc(PByte(Run), Delta);
  end;
end;

//------------------------------------------------------------------------------------------------------------

{$IFDEF VER100}
function ApplyContributors(N: Integer; Contributors: PContributors): TRGB;
{$ELSE}
function ApplyContributors(N: Integer; Contributors: TContributors): TRGB;
{$ENDIF}

var J: Integer;
    RGB: TRGBInt;
    Weight: Integer;
    Pixel: Cardinal;
    Contr: ^TContributor;
    
begin
  RGB.R := 0;
  RGB.G := 0;
  RGB.B := 0;
  Contr := @Contributors[0];
  for J := 0 to N - 1 do
  begin
    Weight := Contr.Weight;
    Pixel := Contr.Pixel;
    Inc(RGB.r, CurrentLineR[Pixel] * Weight);
    Inc(RGB.g, CurrentLineG[Pixel] * Weight);
    Inc(RGB.b, CurrentLineB[Pixel] * Weight);

    Inc(Contr);
  end;

  Result.R := IntToByte(RGB.R div 256);
  Result.G := IntToByte(RGB.G div 256);
  Result.B := IntToByte(RGB.B div 256);
end;

//------------------------------------------------------------------------------------------------------------

procedure DoStretch(Filter: TFilterFunction; Radius: Single; Source, Target: TBitmap);

// This is the actual scaling routine. Target must be allocated already with sufficient size. Source must
// contain valid data, Radius must not be 0 and Filter must not be nil.

var
  ScaleX,
  ScaleY: Single;  // Zoom scale factors
  I, J,
  K, N: Integer; // Loop variables
  Center: Single; // Filter calculation variables
  Width: Single;
  Weight: Integer; //Single; // Filter calculation variables
  Left, Right: Integer; // Filter calculation variables
  Work: TBitmap;
{$IFDEF VER100}
  ContributorList: PContributorList;
{$ELSE}
  ContributorList: TContributorList;
{$ENDIF}
  SourceLine,
  DestLine: PPixelArray;
  DestPixel: PRGB;
  Delta,
  DestDelta: Integer;
  SourceHeight,
  SourceWidth,
  TargetHeight,
  TargetWidth: Integer;

begin
{$IFDEF VER100}
  ContributorList := nil;
{$ENDIF}
  // shortcut variables
  SourceHeight := Source.Height;
  SourceWidth := Source.Width;
  TargetHeight := Target.Height;
  TargetWidth := Target.Width;
  // create intermediate image to hold horizontal zoom
  Work := TBitmap.Create;
  try
    Work.PixelFormat := pf24Bit;
    Work.Height := SourceHeight;
    Work.Width := TargetWidth;
    if SourceWidth = 1 then ScaleX:= TargetWidth / SourceWidth
                       else ScaleX:= (TargetWidth - 1) / (SourceWidth - 1);
    if SourceHeight = 1 then ScaleY:= TargetHeight / SourceHeight
                        else ScaleY:= (TargetHeight - 1) / (SourceHeight - 1);

    // pre-calculate filter contributions for a row
{$IFDEF VER100}
    SetALength(Pointer(ContributorList), TargetWidth, sizeof(TContributorEntry));
{$ELSE}
    SetLength(ContributorList, TargetWidth);
{$ENDIF}
    // horizontal sub-sampling
    if ScaleX < 1 then
    begin
      // scales from bigger to smaller Width
      Width := Radius / ScaleX;
      for I := 0 to TargetWidth - 1 do
      begin
        ContributorList[I].N := 0;
{$IFDEF VER100}
        SetALength(Pointer(ContributorList[I].Contributors), Trunc(2 * Width + 1), SizeOf(TContributor));
{$ELSE}
        SetLength(ContributorList[I].Contributors, Trunc(2 * Width + 1));
{$ENDIF}
        Center := I / ScaleX;
        Left := Floor(Center - Width);
        Right := Ceil(Center + Width);
        for J := Left to Right do
        begin
          Weight := Round(Filter((Center - J) * ScaleX) * ScaleX * 256);
          if Weight <> 0 then
          begin
            if J < 0 then N := -J
                     else
              if J >= SourceWidth then N := SourceWidth - J + SourceWidth - 1
                                  else N := J;
            K := ContributorList[I].N;
            Inc(ContributorList[I].N);
            ContributorList[I].Contributors[K].Pixel := N;
            ContributorList[I].Contributors[K].Weight := Weight;
          end;
        end;
      end;
    end
    else
    begin
      // horizontal super-sampling
      // scales from smaller to bigger Width
      for I := 0 to TargetWidth - 1 do
      begin
        ContributorList[I].N := 0;
{$IFDEF VER100}
        SetALength(Pointer(ContributorList[I].Contributors), Trunc(2 * Radius + 1), SizeOf(TContributor));
{$ELSE}
        SetLength(ContributorList[I].Contributors, Trunc(2 * Radius + 1));
{$ENDIF}
        Center := I / ScaleX;
        Left := Floor(Center - Radius);
        Right := Ceil(Center + Radius);
        for J := Left to Right do
        begin
          Weight := Round(Filter(Center - J) * 256);
          if Weight <> 0 then
          begin
            if J < 0 then N := -J
                     else
             if J >= SourceWidth then N := SourceWidth - J + SourceWidth - 1
                                 else N := J;
            K := ContributorList[I].N;
            Inc(ContributorList[I].N);
            ContributorList[I].Contributors[K].Pixel := N;
            ContributorList[I].Contributors[K].Weight := Weight;
          end;
        end;
      end;
    end;

    // now apply filter to sample horizontally from Src to Work
{$IFDEF VER100}
    SetALength(Pointer(CurrentLineR), SourceWidth, SizeOf(integer));
    SetALength(Pointer(CurrentLineG), SourceWidth, SizeOf(integer));
    SetALength(Pointer(CurrentLineB), SourceWidth, SizeOf(integer));
{$ELSE}
    SetLength(CurrentLineR, SourceWidth);
    SetLength(CurrentLineG, SourceWidth);
    SetLength(CurrentLineB, SourceWidth);
{$ENDIF}
    for K := 0 to SourceHeight - 1 do
    begin
      SourceLine := Source.ScanLine[K];
      FillLineChache(SourceWidth, 3, SourceLine);
      DestPixel := Work.ScanLine[K];
      for I := 0 to TargetWidth - 1 do
        with ContributorList[I] do
        begin
          DestPixel^ := ApplyContributors(N, ContributorList[I].Contributors);
          // move on to next column
          Inc(DestPixel);
        end;
    end;

    // free the memory allocated for horizontal filter weights, since we need the stucture again
{$IFDEF VER100}
    for I := 0 to TargetWidth - 1 do SetALength(Pointer(ContributorList[I].Contributors),0,0);
    SetALength(Pointer(ContributorList), 0, 0);
{$ELSE}
    for I := 0 to TargetWidth - 1 do ContributorList[I].Contributors := nil;
    ContributorList := nil;
{$ENDIF}

    // pre-calculate filter contributions for a column
{$IFDEF VER100}
    SetALength(Pointer(ContributorList), TargetHeight, sizeof(TContributorEntry));
{$ELSE}
    SetLength(ContributorList, TargetHeight);
{$ENDIF}
    // vertical sub-sampling
    if ScaleY < 1 then
    begin
      // scales from bigger to smaller height
      Width := Radius / ScaleY;
      for I := 0 to TargetHeight - 1 do
      begin
        ContributorList[I].N := 0;
{$IFDEF VER100}
        SetALength(Pointer(ContributorList[I].Contributors), Trunc(2 * Width + 1), SizeOf(TContributor));
{$ELSE}
        SetLength(ContributorList[I].Contributors, Trunc(2 * Width + 1));
{$ENDIF}
        Center := I / ScaleY;
        Left := Floor(Center - Width);
        Right := Ceil(Center + Width);
        for J := Left to Right do
        begin
          Weight := Round(Filter((Center - J) * ScaleY) * ScaleY * 256);
          if Weight <> 0 then
          begin
            if J < 0 then N := -J
                     else
              if J >= SourceHeight then N := SourceHeight - J + SourceHeight - 1
                                   else N := J;
            K := ContributorList[I].N;
            Inc(ContributorList[I].N);
            ContributorList[I].Contributors[K].Pixel := N;
            ContributorList[I].Contributors[K].Weight := Weight;
          end;
        end;
      end
    end
    else
    begin
      // vertical super-sampling
      // scales from smaller to bigger height
      for I := 0 to TargetHeight - 1 do
      begin
        ContributorList[I].N := 0;
{$IFDEF VER100}
        SetALength(Pointer(ContributorList[I].Contributors), Trunc(2 * Radius + 1), SizeOf(TContributor));
{$ELSE}
        SetLength(ContributorList[I].Contributors, Trunc(2 * Radius + 1));
{$ENDIF}
        Center := I / ScaleY;
        Left := Floor(Center - Radius);
        Right := Ceil(Center + Radius);
        for J := Left to Right do
        begin
          Weight := Round(Filter(Center - J) * 256);
          if Weight <> 0 then
          begin
            if J < 0 then N := -J
                     else
              if J >= SourceHeight then N := SourceHeight - J + SourceHeight - 1
                                   else N := J;
            K := ContributorList[I].N;
            Inc(ContributorList[I].N);
            ContributorList[I].Contributors[K].Pixel := N;
            ContributorList[I].Contributors[K].Weight := Weight;
          end;
        end;
      end;
    end;

    // apply filter to sample vertically from Work to Target
{$IFDEF VER100}
    SetALength(Pointer(CurrentLineR), SourceHeight, SizeOf(integer));
    SetALength(Pointer(CurrentLineG), SourceHeight, SizeOf(integer));
    SetALength(Pointer(CurrentLineB), SourceHeight, SizeOf(integer));
{$ELSE}
    SetLength(CurrentLineR, SourceHeight);
    SetLength(CurrentLineG, SourceHeight);
    SetLength(CurrentLineB, SourceHeight);
{$ENDIF}


    SourceLine := Work.ScanLine[0];
    Delta := Integer(Work.ScanLine[1]) - Integer(SourceLine);
    DestLine := Target.ScanLine[0];
    DestDelta := Integer(Target.ScanLine[1]) - Integer(DestLine);
    for K := 0 to TargetWidth - 1 do
    begin
      DestPixel := Pointer(DestLine);
      FillLineChache(SourceHeight, Delta, SourceLine);
      for I := 0 to TargetHeight - 1 do
        with ContributorList[I] do
        begin
          DestPixel^ := ApplyContributors(N, ContributorList[I].Contributors);
          Inc(Integer(DestPixel), DestDelta);
        end;
      Inc(SourceLine);
      Inc(DestLine);
    end;

    // free the memory allocated for vertical filter weights
{$IFDEF VER100}
    for I := 0 to TargetHeight - 1 do SetALength(Pointer(ContributorList[I].Contributors),0,0);
    SetALength(Pointer(ContributorList), 0, 0);
{$ELSE}
    for I := 0 to TargetHeight - 1 do ContributorList[I].Contributors := nil;
    ContributorList := nil;
{$ENDIF}

  finally
    Work.Free;
{$IFDEF VER100}
    SetALength(Pointer(CurrentLineR), 0, 0);
    SetALength(Pointer(CurrentLineG), 0, 0);
    SetALength(Pointer(CurrentLineB), 0, 0);
{$ELSE}
    CurrentLineR := nil;
    CurrentLineG := nil;
    CurrentLineB := nil;
{$ENDIF}
  end;
end;

//------------------------------------------------------------------------------------------------------------

{$IFDEF VER100}
procedure Stretch1(NewWidth, NewHeight: Cardinal; Filter: TResamplingFilter; Radius: Single; Source, Target: TBitmap);
{$ELSE}
procedure Stretch(NewWidth, NewHeight: Cardinal; Filter: TResamplingFilter; Radius: Single; Source, Target: TBitmap);
{$ENDIF}

// Scaled the source bitmap to the given size (NewWidth, NewHeight) and stores the result in Target.
// Filter describes the filter function to be applied and Radius the size of the filter area.
// Is Radius = 0 then the recommended will be used (see DefaultFilterRadius).

begin
  if Radius = 0 then Radius := DefaultFilterRadius[Filter];
  Target.FreeImage;
  Target.PixelFormat := pf24Bit;
  Target.Width := NewWidth;
  Target.Height := NewHeight;
  Source.PixelFormat := pf24Bit;
  DoStretch(FilterList[Filter], Radius, Source, Target);
end;

//------------------------------------------------------------------------------------------------------------

{$IFDEF VER100}
procedure Stretch2(NewWidth, NewHeight: Cardinal; Filter: TResamplingFilter; Radius: Single; Source: TBitmap);
{$ELSE}
procedure Stretch(NewWidth, NewHeight: Cardinal; Filter: TResamplingFilter; Radius: Single; Source: TBitmap);
{$ENDIF}

var Target: TBitmap;

begin
  if Radius = 0 then Radius := DefaultFilterRadius[Filter];
  Target := TBitmap.Create;
  try
    Target.PixelFormat := pf24Bit;
    Target.Width := NewWidth;
    Target.Height := NewHeight;
    Source.PixelFormat := pf24Bit;
    DoStretch(FilterList[Filter], Radius, Source, Target);
    Source.Assign(Target);
  finally
    Target.Free;
  end;
end;

//----------------- TExtraGraphic --------------------------------------------------------------------------------------

procedure TExtraGraphic.LoadFromFile(const FileName: String);

begin
  if NVLibLoaded then Handle := NViewLibLoad(PChar(FileName), False);
end;

//----------------- TAutodeskGraphic -----------------------------------------------------------------------------------

procedure TAutodeskGraphic.LoadFromFile(const FileName: string);

var Stream: TFileStream;

begin
  Stream := TFileStream.Create(FileName, fmOpenRead or fmShareDenyWrite);
  try
    LoadFromStream(Stream);
  finally
    Stream.Free;
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TAutodeskGraphic.LoadFromStream(Stream: TStream);

type
  TFileHeader = packed record
    Width,
    Height,
    XCoord,
    YCoord: Word;
    Depth,
    Compress: Byte;
    DataSize: Cardinal;
    Reserved: array[0..15] of Byte;
  end;

var
  FileID: Word;
  FileHeader: TFileHeader;
  LogPalette: TMaxLogPalette;
  I: Integer;

begin
  with Stream do
  begin
    Read(FileID, 2);
    if FileID <> $9119 then raise Exception.Create('Cannot load image. Only old style autodesk images are supported.')
                       else
    begin
      // read image dimensions
      Read(FileHeader, SizeOf(FileHeader));
      // read palette entries and create a palette
      FillChar(LogPalette, SizeOf(LogPalette), 0);
      LogPalette.palVersion := $300;
      LogPalette.palNumEntries := 256;
      for I := 0 to 255 do
      begin
        Read(LogPalette.palPalEntry[I], 3);
        LogPalette.palPalEntry[I].peBlue := LogPalette.palPalEntry[I].peBlue shl 2;
        LogPalette.palPalEntry[I].peGreen := LogPalette.palPalEntry[I].peGreen shl 2;
        LogPalette.palPalEntry[I].peRed := LogPalette.palPalEntry[I].peRed shl 2;
      end;

      // setup bitmap properties
      PixelFormat := pf8Bit;
      Palette := CreatePalette(PLogPalette(@LogPalette)^);
      Width := FileHeader.Width;
      Height := FIleHeader.Height;
      // finally read image data
      for I := 0 to Height - 1 do
        Read(Scanline[I]^, FileHeader.Width);
    end;
  end;
end;

//----------------- TSGIGraphic ----------------------------------------------------------------------------------------

procedure TSGIGraphic.GetRow(Stream: TStream; Buffer: Pointer; Line, Component: Cardinal);

var Source,
    Target: PByte;
    Pixel: Byte;
    Count: Cardinal;

begin
  with Stream do
    // compressed image?
    if (FImageType and $FF00) = $0100 then
    begin
      Position := FStartPosition + FRowStart[Line + Component * Cardinal(Height)];
      Read(FRowBuffer^, FRowSize[Line + Component * Cardinal(Height)]);
      Source := FRowBuffer;
      Target := Buffer;
      while True do
      begin
        Pixel := Source^;
        Inc(Source);
        Count := Pixel and $7F;
        if Count = 0 then Break;

        if (Pixel and $80) <> 0 then
          while Count > 0 do
          begin
            Target^ := Source^;
            Inc(Target);
            Inc(Source);
            Dec(Count);
          end
        else
        begin
          Pixel := Source^;
          Inc(Source);
          while Count > 0 do
          begin
            Target^ := Pixel;
            Inc(Target);
            Dec(Count);
          end;
        end;
      end;
    end
    else
    begin
      // no, not a compressed image, so just read the bytes
      Stream.Position := FStartPosition + 512 + (Line * Cardinal(Width)) + (Component * Cardinal(Width) * Cardinal(Height));
      Stream.Read(Buffer^, Width);
    end;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure SwapShort(P: PWord; Count: Cardinal);

begin
  while Count > 0 do
  begin
    P^ := Swap(P^);
    Inc(P);
    Dec(Count);
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure SwapLong(P: PInteger; Count: Cardinal);
begin
  while Count > 0 do
  begin
    P^ := Swap(LoWord(P^)) shl 16 + Swap(HiWord(P^));
    Inc(P);
    Dec(Count);
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

function TSGIGraphic.InitStructures(Stream: TStream): Cardinal;

// allocates memory for row positions and sizes buffers and returns type of image
// 4 - RGBA
// 3 - RGB
// else - 256 gray values

var
  Count: Cardinal;

  ImageRec: packed record
    Magic,
    ImageType,
    Dim,
    XSize,            // width of image
    YSize,            // height of image
    ZSize: Word;      // number of planes in image (3 for RGB etc.)
  end;

begin
  Result := 0; // shut up compiler...
  with Stream do
  try
    Read(ImageRec, 12);
    FImageType := ImageRec.ImageType;

    // SGI images are stored in big endian style, so we need to swap all bytes in the header
    SwapShort(@ImageRec.Magic, 6);
    GetMem(FRowBuffer, ImageRec.XSize * 256);

    if (FImageType and $FF00) = $0100 then
    begin
      Count := ImageRec.YSize * ImageRec.ZSize * SizeOf(Cardinal);
      GetMem(FRowStart, Count);
      GetMem(FRowSize, Count);
      Stream.Position := FStartPosition + 512;
      // read line starts and sizes from stream
      Read(FRowStart^, Count);
      SwapLong(PInteger(FRowStart), Count div SizeOf(Cardinal));
      Read(FRowSize^, Count);
      SwapLong(PInteger(FRowSize), Count div SizeOf(Cardinal));
    end;
    Result := ImageRec.ZSize;
    Width := ImageRec.XSize;
    Height := ImageRec.YSize;
  except
    if Assigned(FRowBuffer) then FreeMem(FRowBuffer);
    if Assigned(FRowStart) then FreeMem(FRowStart);
    if Assigned(FRowSize) then FreeMem(FRowSize);
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TSGIGraphic.LoadFromFile(const FileName: String);

var Stream: TFileStream;

begin
  Stream := TFileStream.Create(FileName, fmOpenRead or fmShareDenyWrite);
  try
    LoadFromStream(Stream);
  finally
    Stream.Free;
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TSGIGraphic.LoadFromStream(Stream: TStream);

var X, Y,
    ImageType: Integer;
    RedBuffer,
    GreenBuffer,
    BlueBuffer,
    AlphaBuffer,
    R, G, B, A,
    Target: PByte;
    LogPalette: TMaxLogPalette;

begin
  // keep start position for seek operations
  FStartPosition := Stream.Position;
  // allocate memory and do endian to endian conversion
  ImageType := InitStructures(Stream);
  // read lines and put it into the bitmap
  case ImageType of
    4: // RGBA image
      begin
        PixelFormat := pf32Bit;
        GetMem(RedBuffer, Width);
        GetMem(GreenBuffer, Width);
        GetMem(BlueBuffer, Width);
        GetMem(AlphaBuffer, Width);
        for  Y := 0 to Height - 1 do
        begin
          GetRow(Stream, RedBuffer, Y, 0);
          GetRow(Stream, GreenBuffer, Y, 1);
          GetRow(Stream, BlueBuffer, Y, 2);
          GetRow(Stream, AlphaBuffer, Y, 3);
          Target := ScanLine[Height - Y - 1];
          R := RedBuffer;
          G := GreenBuffer;
          B := BlueBuffer;
          A := AlphaBuffer;
          // convert single component buffers into a scanline (note: Windows bitmaps are in
          // format BGRA)
          for X := 0 to Width - 1 do
          begin
            Target^ := B^;
            Inc(Target);
            Inc(B);
            Target^ := G^;
            Inc(Target);
            Inc(G);
            Target^ := R^;
            Inc(Target);
            Inc(R);
            Target^ := A^;
            Inc(Target);
            Inc(A);
          end;
        end;
        FreeMem(RedBuffer);
        FreeMem(GreenBuffer);
        FreeMem(BlueBuffer);
        FreeMem(AlphaBuffer);
      end;
    3: // RGB image
      begin
        PixelFormat := pf24Bit;
        GetMem(RedBuffer, Width);
        GetMem(GreenBuffer, Width);
        GetMem(BlueBuffer, Width);
        for  Y := 0 to Height - 1 do
        begin
          GetRow(Stream, RedBuffer, Y, 0);
          GetRow(Stream, GreenBuffer, Y, 1);
          GetRow(Stream, BlueBuffer, Y, 2);
          Target := ScanLine[Height - Y - 1];
          R := RedBuffer;
          G := GreenBuffer;
          B := BlueBuffer;
          // convert single component buffers into a scanline (note: Windows bitmaps are in
          // format BGR)
          for X := 0 to Width - 1 do
          begin
            Target^ := B^;
            Inc(Target);
            Inc(B);
            Target^ := G^;
            Inc(Target);
            Inc(G);
            Target^ := R^;
            Inc(Target);
            Inc(R);
          end;
        end;
        FreeMem(RedBuffer);
        FreeMem(GreenBuffer);
        FreeMem(BlueBuffer);
      end;
  else
    // any other format is interpreted as being 256 gray scales
    PixelFormat := pf8Bit;
    FillChar(LogPalette, SizeOf(LogPalette), 0);
    LogPalette.palVersion := $300;
    LogPalette.palNumEntries := 256;
    for Y := 0 to 255 do
    begin
      LogPalette.palPalEntry[Y].peBlue := Y;
      LogPalette.palPalEntry[Y].peGreen := Y;
      LogPalette.palPalEntry[Y].peRed := Y;
    end;

    // setup bitmap properties
    Palette := CreatePalette(PLogPalette(@LogPalette)^);
    for  Y := 0 to Height - 1 do
      GetRow(Stream, ScanLine[Height - Y - 1], Y, 0);
  end;

  // free all other intermediate data
  if Assigned(FRowBuffer) then FreeMem(FRowBuffer);
  FRowBuffer := nil;
  if Assigned(FRowStart) then FreeMem(FRowStart);
  FRowStart := nil;
  if Assigned(FRowSize) then FreeMem(FRowSize);
  FRowSize := nil;
  if Assigned(FRowBuffer) then FreeMem(FRowBuffer);
  FRowBuffer := nil;
end;

//----------------------------------------------------------------------------------------------------------------------

function InitImageLibrary: Boolean;

// load the import library and get proc addresses

var OldError: Integer;

begin
  OldError := SetErrorMode(SEM_NOOPENFILEERRORBOX);
  try
    try
      NVLibHandle := LoadLibrary(NVLibrary);
      if NVLibHandle = 0 then Abort;
      NViewLibSetLanguage := GetProcAddress(NVLibHandle, 'NViewLibSetLanguage');
      NViewLibLoad := GetProcAddress(NVLibHandle, 'NViewLibLoad');
      // Delphi comes with an own JPEG implmementation but this seems to
      // have a few bugs. I could sometimes not load images which can be loaded
      // with NViewLib.
      TPicture.RegisterFileFormat('jpg', 'JPG images', TExtraGraphic);
      TPicture.RegisterFileFormat('gif', 'GIF images', TExtraGraphic);
      TPicture.RegisterFileFormat('pcx', 'PCX images', TExtraGraphic);
      TPicture.RegisterFileFormat('tga', 'TGA images', TExtraGraphic);
      Result := True;
    except
      Result := False;
    end;
  finally
    SetErrorMode(OldError);
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure SetupLanguage;

// set up the language used in the image library

begin
  // determine user default language for localized messages
  case GetUserDefaultLangID and $3FF of
    LANG_GERMAN:
      NViewLibSetLanguage('German');
    LANG_ITALIAN:
      NViewLibSetLanguage('Italian');
    LANG_DUTCH:
      NViewLibSetLanguage('Dutch');
    LANG_PORTUGUESE:
      NViewLibSetLanguage('Portuguese');
    LANG_SPANISH:
      NViewLibSetLanguage('Spanish');
    LANG_JAPANESE:
      NViewLibSetLanguage('Japanese')
  else
    NViewLibSetLanguage('English');
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure UnloadImageLibrary;

begin
  if NVLibLoaded then
  begin
    TPicture.UnregisterGraphicClass(TExtraGraphic);
    FreeLibrary(NVLibhandle);
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

initialization
  TPicture.RegisterFileFormat('bw', 'SGI black/white images', TSGIGraphic);
  TPicture.RegisterFileFormat('rgb', 'SGI true color images', TSGIGraphic);
  TPicture.RegisterFileFormat('cel', 'Autodesk image', TAutodeskGraphic);
  TPicture.RegisterFileFormat('pic', 'Autodesk image', TAutodeskGraphic);
  NVLibLoaded := InitImageLibrary;
  if NVLibLoaded then SetupLanguage;
finalization
  TPicture.UnregisterGraphicClass(TSGIGraphic);
  UnloadImageLibrary;
end.