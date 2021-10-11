unit Main;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
                                                            aiOGL, OpenGL,
  StdCtrls, ExtCtrls, mmSystem;

type
  TMyglObject = class(TglObject)
  public
    Y,Z: single;
    Angle: TVector;
    NextObject: TMyglObject;
    D: single;
    procedure Draw_; override;
  end;


  TMyglScene = class(TglScene)
    procedure Draw; override;
  end;

  TCaterpillar = array[0..73] of TMyglObject;
  TWheels = array[0..10] of TMyglObject;

  TStage = record
    BeginTime: cardinal;
    Duration: cardinal;
    case integer of
      0: (BeginSpeed, EndSpeed: single);
      1: (BeginAngle, EndAngle: single);
      2: (FromPoint, ToPoint: TVector);
  end;

  TForm1 = class(TForm)
    LB: TListBox;
    procedure FormCreate(Sender: TObject);
    procedure FormMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure FormMouseMove(Sender: TObject; Shift: TShiftState; X,
      Y: Integer);
    procedure FormMouseWheelDown(Sender: TObject; Shift: TShiftState;
      MousePos: TPoint; var Handled: Boolean);
    procedure FormMouseWheelUp(Sender: TObject; Shift: TShiftState;
      MousePos: TPoint; var Handled: Boolean);
    procedure FormKeyPress(Sender: TObject; var Key: Char);
    procedure FormDestroy(Sender: TObject);
  private
    TankScene: TMyglScene;
    ParentObject: TglObject;
    LastX,LastY: integer;
    LeftTracks: TCaterpillar;
    RightTracks: TCaterpillar;

    LeftLinks: TCaterpillar;
    RightLinks: TCaterpillar;

    LeftWheels: TWheels;
    RightWheels: TWheels;
    Turret: array [0..15] of TglObject;
    Hull: array[0..20] of TglObject;
    LastTime,StartTime,RunTime: cardinal;
    Progress: single;
//    Al,LookAl: single;
//    LAStage: byte;
    FLeftMove: boolean; FRightMove: boolean;
    procedure CreateLeftSide;
    procedure CreateRightSide;
    procedure Idle(Sender: TObject; var Done: Boolean);
    procedure AssembleTurret;
    procedure AssembleHull;
    procedure CreateGround;
    procedure CutAntenna;
    procedure SetLeftMove(AMove: boolean);
    procedure SetRightMove(AMove: boolean);
    procedure TracksSagging(Ahead: boolean);
    procedure CorrectLinks;
  public
    { Public declarations }
//   MMTimer : integer; // Код мультимедийного таймера
    property MoveAheadLeft: boolean read FLeftMove write SetLeftMove;
    property MoveAheadRight: boolean read FRightMove write SetRightMove;
  end;

var
  Form1: TForm1;
  b: boolean;
  shift: single;
  RRl, RRr: shortint;
  KKKl,KKKr: byte;
 // q: GLUquadricObj;

const
  GroundTexureRepCount = 20;
  GroundLength = 4000; GroundWidth = 2000;
  Speed30 = 30 * 1.35;
  SwayAngle = 2.5;
  LeftCaterpillarStages: array [0..8] of TStage = ((BeginTime: 1000; Duration: 6000; BeginSpeed: 0; EndSpeed: Speed30),  // разгон
                                                   (BeginTime: 6000; Duration: 5000; BeginSpeed: Speed30; EndSpeed: Speed30), // торможение
                                                   (BeginTime: 11000; Duration: 2000; BeginSpeed: 0; EndSpeed: 0),
                                                   (BeginTime: 19000; Duration: 3000; BeginSpeed: 0; EndSpeed: 10*1.35), // назад едем
                                                   (BeginTime: 22000; Duration: 7000; BeginSpeed: 10*1.35; EndSpeed: 10*1.35),
                                                   (BeginTime: 29000; Duration: 1000; BeginSpeed: 10*1.35; EndSpeed: 0), // остановка
                                                   (BeginTime: 31000; Duration: 6000; BeginSpeed: 5*1.35; EndSpeed: 5*1.35),
                                                   (BeginTime: 37000; Duration: 10000; BeginSpeed: 5*1.35; EndSpeed: 5*1.35),
                                                   (BeginTime: 47000; Duration: 4000; BeginSpeed: 5*1.35; EndSpeed: 5*1.35));
  SwayHullStages: array [0..14] of TStage = ((BeginTime: 1000; Duration: 200; BeginAngle: 0; EndAngle: -2),
                                            (BeginTime: 1200; Duration: 400; BeginAngle: -2; EndAngle: -1),
                                            (BeginTime: 1600; Duration: 1200; BeginAngle: -1; EndAngle: -3),
                                            (BeginTime: 2800; Duration: 600; BeginAngle: -3; EndAngle: -2),
                                            (BeginTime: 3400; Duration: 600; BeginAngle: -2; EndAngle: -3),
                                            (BeginTime: 6000; Duration: 4000; BeginAngle: 999; EndAngle: -3),
                                            (BeginTime: 10000; Duration: 1000; BeginAngle: 999; EndAngle: 0),
                                            (BeginTime: 11000; Duration: 500; BeginAngle: 0; EndAngle: 4),
                                            (BeginTime: 11500; Duration: 500; BeginAngle: 3; EndAngle: 1),
                                            (BeginTime: 12000; Duration: 500; BeginAngle: 1; EndAngle: 4),
                                            (BeginTime: 12500; Duration: 6000; BeginAngle: 999; EndAngle: 4),
                                            (BeginTime: 19000; Duration: 300; BeginAngle: 0; EndAngle: 2),
                                            (BeginTime: 19300; Duration: 4000; BeginAngle: 999; EndAngle: 2),
                                            (BeginTime: 29500; Duration: 300; BeginAngle: 0; EndAngle: -1),
                                            (BeginTime: 29800; Duration: 4200; BeginAngle: 999; EndAngle: -1));
  LookAtStages: array [0..2] of TStage = ((BeginTime: 1000; Duration: 11000; FromPoint: (X:250; Y:150; Z:12); ToPoint: (X:250; Y:-150; Z:0)),
                                          (BeginTime: 21000; Duration: 10000; FromPoint: (X:250; Y:-150; Z:0); ToPoint: (X:-200; Y:-320; Z:12)),
                                          (BeginTime: 33000; Duration: 15000; FromPoint: (X:-200; Y:-320; Z:12); ToPoint: (X:-200; Y:150; Z:100)));

  TurretTurnStages: array [0..2] of TStage = ((BeginTime: 32000; Duration: 2000; BeginAngle: 0; EndAngle: 50),
                                              (BeginTime: 34000; Duration: 4000; BeginAngle: 50; EndAngle: -50),
                                              (BeginTime: 38000; Duration: 500; BeginAngle: -50; EndAngle: -39));

  HullTurnStages: array [0..2] of TStage = ((BeginTime: 31000; Duration: 6000; BeginAngle: 0; EndAngle: -120),
                                            (BeginTime: 37000; Duration: 10000; BeginAngle: -120; EndAngle: 80),
                                            (BeginTime: 47000; Duration: 4000; BeginAngle: 80; EndAngle: 0));
implementation

{$R *.DFM}

procedure TMyglScene.Draw;
begin
  inherited;
//  glPushMatrix();
//  glRotatef(90, 0, 1, 0);
//  glTranslatef(70, -250, -100);

//  gluCylinder(q, 30, 30, 150, 20, 20);
//  gluDisk(q, 0, 40, 20, 20);
//  glPopMatrix();

end;

procedure TMyglObject.Draw_;
begin
  if Name = 'Ground' then
    begin
      glMatrixMode(GL_TEXTURE);
  //    glPushMatrix;
      glTranslatef(0, -RRl * shift * GroundTexureRepCount * 2 / GroundLength, 0);
      glCallList(GLListNumber);
  //    glPopMatrix;
      glMatrixMode(GL_MODELVIEW);
    end else
    inherited;
end;

{procedure TForm1.RotateX(glObject: TglObject; al: single);
var

  i: integer;
  sinal,cosal: single;
  yy,zz: single;
begin
  al:= al * pi / 180;
  sinal:= sin(al);
  cosal:= cos(al);

  with glObject do
    for i:= 0 to VertexCount - 1 do
      begin
//x' = x;
//y' = y0+(y-y0)*cos(A)+(z0-z)*sin(alpha);
//z' = z0+(y-y0)*sin(A)+(z-z0)*cos(alpha);
        yy:= y0 + (Vertices[i].Vector.Y - y0) * cosal + (z0 - Vertices[i].Vector.Z) * sinal;
        zz:= z0 + (Vertices[i].Vector.Y - y0) * sinal + (Vertices[i].Vector.Z - z0) * cosal;
        Vertices[i].Vector.Y:= yy;
        Vertices[i].Vector.Z:= zz;
      end;
end; }

procedure TForm1.SetLeftMove(AMove: boolean);
var
  i: integer;
begin
  if AMove = FLeftMove then
    Exit;
  TracksSagging(AMove);
  if AMove then
    begin
      KKKl:= 38; RRl:= -1;
      for i:= 1 to 73 do
        begin
          LeftTracks[i-1].NextObject:= LeftTracks[i];
          LeftLinks[i-1].NextObject:= LeftLinks[i];
       //   RightTracks[i-1].NextObject:= RightTracks[i];
        //  RightLinks[i-1].NextObject:= RightLinks[i];
        end;
      LeftTracks[73].NextObject:= LeftTracks[0];
      LeftLinks[73].NextObject:= LeftLinks[0];
   ///   RightTracks[73].NextObject:= RightTracks[0];
    //  RightLinks[73].NextObject:= RightLinks[0];
    end else
    begin
      KKKl:= 39; RRl:= 1;
      for i:= 1 to 73 do
        begin                                                    
          LeftTracks[i].NextObject:= LeftTracks[i-1];
          LeftLinks[i].NextObject:= LeftLinks[i-1];
      //    RightTracks[i].NextObject:= RightTracks[i-1];
        //  RightLinks[i].NextObject:= RightLinks[i-1];
        end;
      LeftTracks[0].NextObject:= LeftTracks[73];
      LeftLinks[0].NextObject:= LeftLinks[73];
    //  RightTracks[0].NextObject:= RightTracks[73];
    //  RightLinks[0].NextObject:= RightLinks[73];
    end;
  FLeftMove:= AMove;
end;

procedure TForm1.SetRightMove(AMove: boolean);
var
  i: integer;
begin
  if AMove = FRightMove then
    Exit;
  if AMove then
    begin
      KKKr:= 38; RRr:= -1;
      for i:= 1 to 73 do
        begin
        //  LeftTracks[i-1].NextObject:= LeftTracks[i];
        //  LeftLinks[i-1].NextObject:= LeftLinks[i];
          RightTracks[i-1].NextObject:= RightTracks[i];
          RightLinks[i-1].NextObject:= RightLinks[i];
        end;
    //  LeftTracks[73].NextObject:= LeftTracks[0];
    //  LeftLinks[73].NextObject:= LeftLinks[0];
      RightTracks[73].NextObject:= RightTracks[0];
      RightLinks[73].NextObject:= RightLinks[0];
    end else
    begin
      KKKr:= 39; RRr:= 1;
      for i:= 1 to 73 do
        begin
       //   LeftTracks[i].NextObject:= LeftTracks[i-1];
       //   LeftLinks[i].NextObject:= LeftLinks[i-1];
          RightTracks[i].NextObject:= RightTracks[i-1];
          RightLinks[i].NextObject:= RightLinks[i-1];
        end;
    //  LeftTracks[0].NextObject:= LeftTracks[73];
    //  LeftLinks[0].NextObject:= LeftLinks[73];
      RightTracks[0].NextObject:= RightTracks[73];
      RightLinks[0].NextObject:= RightLinks[73];
    end;
  FRightMove:= AMove;
end;

procedure TForm1.TracksSagging(Ahead: boolean);
var
  i: integer;
begin
// сделать провисание траков (только левых)
// между направляющим колесом и первым роликом
  for i:= 63 to 67 do
    begin
      if Ahead then
        begin
          LeftTracks[i].Z:= LeftTracks[i].Z - (i - 62) * 0.5;
          LeftTracks[i].Angle.X:= LeftTracks[i].Angle.X + 3;
          LeftTracks[i+9-((i-62)*2-1)].Z:= LeftTracks[i].Z;
          LeftTracks[i+9-((i-62)*2-1)].Angle.X:= LeftTracks[i+9-((i-62)*2-1)].Angle.X - 3;
        end else
        begin
          LeftTracks[i].Z:= LeftTracks[i].Z + (i - 62) * 0.5;
          LeftTracks[i].Angle.X:= LeftTracks[i].Angle.X - 3;
          LeftTracks[i+9-((i-62)*2-1)].Z:= LeftTracks[i].Z;
          LeftTracks[i+9-((i-62)*2-1)].Angle.X:= LeftTracks[i+9-((i-62)*2-1)].Angle.X + 3;
        end;
    end;
// между роликами
  for i:= 53 to 57 do
    begin
      if Ahead then
        begin
          LeftTracks[i].Z:= LeftTracks[i].Z - (i - 52) * 0.5;
          LeftTracks[i].Angle.X:= LeftTracks[i].Angle.X + 3;
          LeftTracks[i+9-((i-52)*2-1)].Z:= LeftTracks[i].Z;
          LeftTracks[i+9-((i-52)*2-1)].Angle.X:= LeftTracks[i+9-((i-52)*2-1)].Angle.X - 3;
        end else
        begin
          LeftTracks[i].Z:= LeftTracks[i].Z + (i - 52) * 0.5;
          LeftTracks[i].Angle.X:= LeftTracks[i].Angle.X - 3;
          LeftTracks[i+9-((i-52)*2-1)].Z:= LeftTracks[i].Z;
          LeftTracks[i+9-((i-52)*2-1)].Angle.X:= LeftTracks[i+9-((i-52)*2-1)].Angle.X + 3;
        end;
    end;
// между ведущим колесом и вторым роликом
  for i:= 43 to 47 do
    if Ahead then
      begin
        LeftTracks[i].Z:= LeftTracks[i].Z - (i - 42) * 0.5;
        LeftTracks[i].Angle.X:= LeftTracks[i].Angle.X + 3;
        LeftTracks[i+9-((i-42)*2-1)].Z:= LeftTracks[i].Z;
        LeftTracks[i+9-((i-42)*2-1)].Angle.X:= LeftTracks[i+9-((i-42)*2-1)].Angle.X - 3;
      end else
      begin
        LeftTracks[i].Z:= LeftTracks[i].Z + (i - 42) * 0.5;
        LeftTracks[i].Angle.X:= LeftTracks[i].Angle.X - 3;
        LeftTracks[i+9-((i-42)*2-1)].Z:= LeftTracks[i].Z;
        LeftTracks[i+9-((i-42)*2-1)].Angle.X:= LeftTracks[i+9-((i-42)*2-1)].Angle.X + 3;
      end;
end;

procedure TForm1.CorrectLinks;
var
  i: integer;
begin
  for i:= 3 to 7 do
    with LeftLinks[i] do begin Angle.X:= Angle.X - 12; Y:= Y + 3; Z:= Z - 2; end;
  with LeftLinks[8] do begin Angle.X:= Angle.X - 6; Y:= Y + 2; Z:= Z - 0.8; end;

  for i:= 9 to 32 do
    with LeftLinks[i] do begin Angle.X:= Angle.X - 7; Y:= Y + 2;  end;
  with LeftLinks[32] do Y:= Y - 1;
  for i:= 33 to 37 do
    with LeftLinks[I] do begin Angle.X:= Angle.X - 9; Y:= Y + 1; Z:= Z + 1; end;
  for i:= 43 to 71 do
    with LeftLinks[i] do begin Angle.X:= Angle.X - 12; Y:= Y - 3;  end;
  with LeftLinks[72] do begin Angle.X:= Angle.X - 7; Y:= Y - 2; Z:= Z + 0; end;
end;

procedure TForm1.CreateLeftSide;
var
  glObject: TGLObject;
  Mx,Mn,v1,v2: TVector;
  i: integer;
  a1,a2: single;
  y1: single;
  num: integer;
  y00,z00: single;

function CreateTrack: TMyglObject;
begin
  Result:= TMyglObject.Create;
  TankScene.AddObject(Result);
  Result.Assign(ParentObject);
  Result.LocalTranslate.Y:= y00; Result.LocalTranslate.Z:= z00;
  LeftTracks[num]:= Result;
  Inc(num);
end;

function CreateLink: TMyglObject;
begin
  Result:= TMyglObject.Create;
  TankScene.AddObject(Result);
  Result.Assign(ParentObject);
  Result.LocalTranslate.Y:= y00; Result.LocalTranslate.Z:= z00;
  LeftLinks[num]:= Result;
  Inc(num);
end;

function CreateWheel(WheelName: string): TMyglObject;
var
  Mx,Mn: TVector;
begin
  Result:= TMyglObject.Create;
  TankScene.AddObject(Result);
  Result.Assign(TankScene.GetObject(WheelName));
  Mx:= Result.Max; Mn:= Result.Min;
  Result.LocalTranslate.Y:= (Mx.Y + Mn.Y) / 2; Result.LocalTranslate.Z:= (Mx.Z + Mn.Z) / 2;
  TankScene.DeleteObject(TankScene.GetObject(WheelName));
  Result.D:= Mx.Y - Mn.Y;
end;

begin
 // glEnable(gl_Normalize);
//    левый передний ролик
  GLObject:= TglObject.Create;
  TankScene.AddObject(GLObject);
  GLObject.Assign(TankScene.GetObject('rowheel_l6'));
  GLObject.Name:= 'RollLeft_1';
  GLObject.Scale_(1, 0.5, 0.5);
  GLObject.Translate_(0, 24, -9);

//    левый задний ролик
  GLObject:= TglObject.Create;
  TankScene.AddObject(GLObject);
  GLObject.Assign(TankScene.GetObject('RollLeft_1'));
  GLObject.Name:= 'RollLeft_2';
  GLObject.Translate_(0, 95, 0);

//    правый передний ролик
  GLObject:= TMyglObject.Create;
  TankScene.AddObject(GLObject);
  GLObject.Assign(TankScene.GetObject('rowheel_14'));
  GLObject.Name:= 'RollRight_1';
  GLObject.Scale_(1, 0.5, 0.5);
  GLObject.Translate_(0, 24, -9);

//    правый задний ролик
  GLObject:= TMyglObject.Create;
  TankScene.AddObject(GLObject);
  GLObject.Assign(TankScene.GetObject('RollRight_1'));
  GLObject.Name:= 'RollRight_2';
  GLObject.Translate_(0, 95, 0);
// y0 и z0 будут нужны для рисования
  glObject:= TankScene.GetObject('rowheel_l6');
  Mx:= glObject.Max; Mn:= glObject.Min;
  y00:= (Mx.Y + Mn.Y) / 2; z00:= (Mx.Z + Mn.Z) / 2;

  num:= 0;
  CreateTrack;                   // начальное звено

// направляющее колесо и вниз
  glObject:= TankScene.GetObject('track42');
  v1:= glObject.Vertices[18].Vector; v2:= glObject.Vertices[20].Vector;
  a1:= arctan((v2.Z - v1.Z) / (v2.Y - v1.Y)) / pi * 180;

  for i:= 41 downto 33 do
    begin
      glObject:= TankScene.GetObject('track' + IntToStr(i));
      v1:= glObject.Vertices[18].Vector; v2:= glObject.Vertices[20].Vector;
      a2:= arctan((v2.Z - v1.Z) / (v2.Y - v1.Y)) / pi * 180;
      with CreateTrack do
        begin
          if (i <= 38) and (i >= 34) then
            Angle.X:= a1 - a2 + 45;
          case i of
            33: begin  Angle.X:= a1 - a2 + 70; y:= 38; z:= -19.5; end;
            34: begin  y:= 33; z:= -18; end;
            35: begin  y:= 25.5; z:= -14.5; end;
            36: begin  y:= 18.5; z:= -10.5; end;
            37: begin  y:= 11; z:= -6.5; end;
            38: begin  Angle.X:= Angle.X-8; y:= 4.5; z:= -3; end;
            39: Angle.X:= a1 - a2 + 12;
            40: Angle.X:= a1 - a2 - 50;
            41: Angle.X:= a2 - a1;
          end;
        end;
      TankScene.DeleteObject(glObject);
    end;

// все оставшиеся траки
  TankScene.GetObject('track').Name:= 'track00';
  y1:= 43.5;
  for i:= 32 downto 0 do
    begin
      with CreateTrack do
        begin
          if (i <= 8) and (i >= 4) then
            Angle.X:= 170;
          case i of
            0:      begin Angle.X:= -65; Y:= 268; Z:= -0.1; end;
            1:      begin Angle.X:= -95; Y:= 268; Z:= -0.1; end;
            2:      begin Angle.X:= -136; Y:= 267; Z:= 2.2; end;
            3:      begin Angle.X:= -170; Y:= 268; Z:= 2.5; end;
            4:      begin Y:= 266; Z:= 0.7; end;
            5:      begin Y:= 259; Z:= -3.9; end;
            6:      begin Y:= 252.5; Z:= -8; end;
            7:      begin Y:= 245.5; Z:= -12.5; end;
            8:      begin Y:= 238; Z:= -16.6; end;
            9:      begin Angle.X:= 160; Y:= 233; Z:= -19.7; end;
//  нижние
            10..32: begin Angle.X:= 135; Y:= y1; Z:= -20; y1:= y1 + 8.55; end;
          end;
        end;
      if i > 9 then
        glObject:= TankScene.GetObject('track' + IntToStr(i)) else
        glObject:= TankScene.GetObject('track0' + IntToStr(i));
      TankScene.DeleteObject(glObject);
    end;

// здесь начинаем создавать недостающие траки
// добавить звено перед прямой
  with CreateTrack do
    begin
      Angle.X:= -47; Y:= 264.5;
    end;
// верхние
  for i:= 30 downto 3 do
    with CreateTrack do
      begin
        Angle.X:= -40; Y:= 34 + (i - 5) * 8.96;
      end;
//  оставшиеся 2 трака
  with CreateTrack do
    begin
      Angle.X:= -45; Y:= 6;
    end;
  CreateTrack.Angle.X:= -32;
  TankScene.DeleteObject(ParentObject);

//  TracksSagging;

  for i:= 0 to 73 do
    with LeftTracks[i] do
      begin
        Name:= 'Track' + IntToStr(i);
        LocalRotate.X:= Angle.X; CurTranslate.Y:= Y; CurTranslate.Z:= Z;
      end;

//  линки
  TankScene.DeleteObject(TankScene.GetObject('trlink'));
  for i:= 10 to 41 do
    TankScene.DeleteObject(TankScene.GetObject('trlink' + IntToStr(i)));
  for i:= 1 to 9 do
    TankScene.DeleteObject(TankScene.GetObject('trlink0' + IntToStr(i)));

  num:= 0;
  ParentObject:= TankScene.GetObject('trlink42');
  for i:= 0 to 73 do
    with CreateLink do
      begin
        Angle.X:= LeftTracks[i].Angle.X;
        Y:= LeftTracks[i].Y ;
        Z:= LeftTracks[i].Z;
      end;

  CorrectLinks;

  TankScene.DeleteObject(ParentObject);



  for i:= 0 to 73 do
    with LeftLinks[i] do
      Name:= 'Link' + IntToStr(i);

  TankScene.GetObject('rowheel_l7').Name:= 'rowheel_7';
  TankScene.GetObject('rowheel_l8').Name:= 'rowheel_8';
  TankScene.GetObject('rowheel_l9').Name:= 'rowheel_9';

  TankScene.GetObject('rowheel_l6').Name:= 'rowheel_l7';
  TankScene.GetObject('rowheel_l').Name:= 'rowheel_l6';
  for i:= 0 to 10 do
    case i of
      0..7: LeftWheels[i]:= CreateWheel('rowheel_l' + IntToStr(i));
      8: LeftWheels[i]:= CreateWheel('RollLeft_1');
      9: LeftWheels[i]:= CreateWheel('RollLeft_2');
     10: LeftWheels[i]:= CreateWheel('Rectangle0');
    end;

  for i:= 0 to 7 do
    RightWheels[i]:= CreateWheel('rowheel_' + IntToStr(i+7));
  RightWheels[8]:= CreateWheel('RollRight_1');
  RightWheels[9]:= CreateWheel('RollRight_2');
  RightWheels[10]:= CreateWheel('Rectangl10');
end;

procedure TForm1.AssembleTurret;
begin
  with TankScene do
    begin
      {Turret[0]:= GetObject('maingun');} Turret[1]:= GetObject('Turret');
      Turret[2]:= GetObject('Rectangle1'); Turret[3]:= GetObject('Rectangle3');
      Turret[4]:= GetObject('Rectangle4'); Turret[5]:= GetObject('Rectangle5');
      Turret[6]:= GetObject('Rectangle6'); Turret[7]:= GetObject('tray');
      Turret[8]:= GetObject('Cylinder01'); Turret[9]:= GetObject('Cylinder02');
      Turret[10]:= GetObject('rdoor'); Turret[11]:= GetObject('ldoor');
      Turret[12]:= GetObject('m2'); Turret[13]:= GetObject('comhatch');
      Turret[14]:= GetObject('ChamferCyl'); Turret[15]:= GetObject('Tube01');
    end;
  end;

procedure TForm1.AssembleHull;
var
  i: integer;
begin
  TankScene.GetObject('s_arml').Name:= 's_arml0';
  for i:= 0 to 6 do
    Hull[i]:= TankScene.GetObject('s_arml' + IntToStr(i));
  with TankScene do
    begin
      Hull[7]:= GetObject('hull_____1'); Hull[8]:= GetObject('Rectangle2');
      Hull[9]:= GetObject('headlight'); Hull[10]:= GetObject('engrill__1');
    end;
  TankScene.GetObject('s_armr').Name:= 's_armr0';
  for i:= 0 to 6 do
    Hull[i+11]:= TankScene.GetObject('s_armr' + IntToStr(i));
  Hull[18]:= TankScene.GetObject('lmudguard');
  Hull[19]:= TankScene.GetObject('rmudguard');
  Hull[20]:= TankScene.GetObject('drhatch');
// левые рычаги
  Hull[0].LocalTranslate:= Vector(0, -118, -39); Hull[1].LocalTranslate:= Vector(0, -81, -43);
  Hull[2].LocalTranslate:= Vector(0, -49, -43); Hull[3].LocalTranslate:= Vector(0, -17, -43);
  Hull[4].LocalTranslate:= Vector(0, 14, -43); Hull[5].LocalTranslate:= Vector(0, 45, -43);
  Hull[6].LocalTranslate:= Vector(0, 76, -43);
  for i:= 0 to 6 do
    Hull[i+11].LocalTranslate:= Hull[i].LocalTranslate;   // это правые рычаги
end;

procedure TForm1.CreateGround;
var
  Material1: TMaterial;
const
  h = -70;
//  c = 10;
begin
  CurScene.AddObject(TMyglObject.Create);
  with CurScene.Objects[CurScene.ObjectCount-1] do
    begin
    //  Frozen:= True;
      Name:= 'Ground';
      VertexCount:= 4;
      Vertices[0].Vector:= Vector(GroundWidth, -GroundLength, h); Vertices[1].Vector:= Vector(GroundWidth, GroundLength, h);
      Vertices[2].Vector:= Vector(-GroundWidth, GroundLength, h); Vertices[3].Vector:= Vector(-GroundWidth, -GroundLength, h);

      FaceCount:= 2;
      Faces[0]:= Face(0, 1, 2); Faces[1]:= Face(0, 2, 3);

      FaceGroupCount:= 1;
      FaceGroups[0].OriginFace:= 0; FaceGroups[0].FaceCount:= 2;
      Material1:= TankScene.Materials.NewMaterial;
      with Material1 do
        begin
          Texture:= TankScene.Materials.NewTexture;
          Texture.FileName:= '2.jpeg'; //'5.jpg'; //'Лам.jpeg'; //brick27.bmp';//'opengl.jpeg';
      GetShadow:= True;
      end;
      FaceGroups[0].Material:= Material1;
      Vertices[0].U:= 0; Vertices[0].V:= GroundTexureRepCount;
      Vertices[1].U:= 0; Vertices[1].V:= 0;
      Vertices[2].U:= GroundTexureRepCount; Vertices[2].V:= 0;
      Vertices[3].U:= GroundTexureRepCount; Vertices[3].V:= GroundTexureRepCount;
      Material1.Ambient:= RGB(255, 255, 255);
       Material1.Diffuse:= RGB(255, 255, 255);
    end;
end;

procedure TForm1.CreateRightSide;
var
  i: integer;
  glo: TMyglObject;
begin
  for i:= 43 to 85 do
    TankScene.DeleteObject(TankScene.GetObject('track' + IntToStr(i)));
  for i:= 43 to 84 do
      TankScene.DeleteObject(TankScene.GetObject('trlink' + IntToStr(i)));

  for i:= 0 to 73 do
    begin
      RightTracks[i]:= TMyglObject.Create;
      TankScene.AddObject(RightTracks[i]);
      glo:= TMyglObject(TankScene.GetObject('track' + IntToStr(i)));
      RightTracks[i].Assign(glo);
      RightTracks[i].CurTranslate.X:= -123;
      RightTracks[i].Y:= glo.Y; RightTracks[i].Z:= glo.Z;
      RightTracks[i].Angle:= glo.Angle;

      RightLinks[i]:= TMyglObject.Create;
      TankScene.AddObject(RightLinks[i]);
      glo:= TMyglObject(TankScene.GetObject('trlink85'));
      RightLinks[i].Assign(glo);
      RightLinks[i].Y:= LeftLinks[i].Y; RightLinks[i].Z:= LeftLinks[i].Z;
      RightLinks[i].Angle:= LeftLinks[i].Angle;
      RightLinks[i].LocalTranslate:= LeftLinks[i].LocalTranslate;
    end;
  TankScene.DeleteObject(TankScene.GetObject('trlink85'));
end;

procedure TForm1.CutAntenna;
var
  i: integer;
  ZMax: single;
  FaceNum: word;
begin
  with Turret[0] do
    for i:= 0 to FaceCount - 1 do
      if Vertices[Faces[i].A].Vector.Z > ZMax then
        begin
          FaceNum:= i;
          ZMax:= Vertices[Faces[i].A].Vector.Z;
        end;
  with Turret[0] do
    for i:= 0 to FaceCount - 1 do
      if Vertices[Faces[i].A].Vector.Z > 41 then
        begin
          Faces[i].A:= 0; Faces[i].B:= 0; Faces[i].C:= 0;
        end;
end;

procedure MyTimerCallBackProg(uTimerID, uMessage: UINT; dwUser, dw1, dw2: DWORD); stdcall;
var
  b: boolean;
begin
  Form1.Idle(nil, b);
end;


procedure TForm1.FormCreate(Sender: TObject);
var
  Max,Min: TVector;
begin
  Progress:= 0; LastTime:= 0;
  TankScene:= TMyglSCene.Create(Self);
  TankScene.LoadFromFile('M1.3ds');

  TankScene.DeleteObject(TankScene.GetObject('Rectangle9'));
  TankScene.DeleteObject(TankScene.GetObject('Rectangle8'));
  TankScene.DeleteObject(TankScene.GetObject('grille'));
  AssembleTurret;
  AssembleHull;

  Max:= TankScene.Max; Min:= TankScene.Min;
  TankScene.EyePoint:= Vector(250, 150 , 12);
  TankScene.UpVector:= Vector(0, 0, 1);
  TankScene.LookAt;

  TankScene.GetObject('lmudguard').Visible:= False;

  ParentObject:= TankScene.GetObject('track42');
  CreateLeftSide;
  CreateRightSide;
  CreateGround;
 // CutAntenna;
  MoveAheadLeft:= True; MoveAheadRight:= True;
  Caption:= Format('%f  %f    %f', [3650 / (Max.X - Min.X), 9828 / (Max.Y - Min.Y), 2438 / (Max.Z - Min.Z)]);

//  TankScene.Lighting.ModelAmbient:= RGB(180, 180, 180);
  TankScene.Lighting.Enabled[1]:= False;
  TankScene.Lighting.Infinity[0]:= True;
  TankScene.Lighting.Direction[0]:= NullVector;
  TankScene.Lighting.SpotCutOff[0]:= 180; TankScene.Lighting.Position[0]:= Vector(0, 200, 300);


  CurScene.Texts:= TglTexts.Create;
  CurScene.Texts.FontFormat:= WGL_FONT_LINES;
  if not CurScene.Texts.AddFont(CurScene.DC, Form1.Font) then
    Caption:= 'Can''t create font';

   with CurScene.Texts.AddText('M1 ABRAMS') do
     begin
       Translate:= Vector(-400, -700, 100); Rotate:= Vector(90, 90, 0);
       Scale:= Vector(200, 200, 200);
       Material:= TMaterial.Create;
       Material.Specular:= clOlive;
     end;

  TankScene.GetNormals;
  TankScene.Render;
  TankScene.Paint;

//  q:= gluNewQuadric;
  Application.OnIdle:= Idle;
end;

procedure TForm1.Idle(Sender: TObject; var Done: Boolean);
var
  t,i,j: cardinal;
  Speed: single;

procedure Caterpillar(Tracks, Links: TCaterpillar; Wheels: TWheels);
var
  i: integer;
  KKK: byte;
  RR: smallint;
begin
//  задет положение траков и линков
  if Tracks[0] = LeftTracks[0] then
    begin KKK:= KKKl; RR:= RRl; end else
    begin KKK:= KKKr; RR:= RRr; end;

  for i:= 0 to 73 do
    begin
      if i = KKK then
        Tracks[KKK].NextObject.Angle.X:= RR * -360 + Tracks[KKK].NextObject.Angle.X ;

      Tracks[i].LocalRotate.X:= Tracks[i].Angle.X + (Tracks[i].NextObject.Angle.X - Tracks[i].Angle.X) * Progress;
      if i = KKK then
        Tracks[KKK].NextObject.Angle.X:= RR * 360 + Tracks[KKK].NextObject.Angle.X ;

      Tracks[i].CurTranslate.Y:= Tracks[i].Y + (Tracks[i].NextObject.Y - Tracks[i].Y) * Progress;
      Tracks[i].CurTranslate.Z:= Tracks[i].Z + (Tracks[i].NextObject.Z - Tracks[i].Z) * Progress;

      if i = KKK then
        Links[KKK].NextObject.Angle.X:= RR * -360 + Links[KKK].NextObject.Angle.X ;
      Links[i].LocalRotate.X:= Links[i].Angle.X + (Links[i].NextObject.Angle.X - Links[i].Angle.X) * Progress;
      if i = KKK then
        Links[KKK].NextObject.Angle.X:= RR * 360 + Links[KKK].NextObject.Angle.X ;

      Links[i].CurTranslate.Y:= Links[i].Y + (Links[i].NextObject.Y - Links[i].Y) * Progress;
      Links[i].CurTranslate.Z:= Links[i].Z + (Links[i].NextObject.Z - Links[i].Z) * Progress;
    end;

    for i:= 0 to 10 do
      case i of
        0..9: Wheels[i].LocalRotate.X:= Wheels[i].LocalRotate.X - RR * shift * 8.55 * 360 / pi / Wheels[i].D;
//  ведущие
        10: Wheels[i].LocalRotate.X:= Wheels[i].LocalRotate.X - RR * shift * 8.55 * 360 / pi / Wheels[i].D * 1.11825;
      end;
end;

// качание корпуса
procedure SwayHull(Angle: single);
var
  i: integer;
begin
  for i:= 0 to 20 do
    Hull[i].Rotate.X:= Angle;
  for i:= 1 to 15 do
    Turret[i].Rotate.X:= Angle;
  for i:= 7 to 10 do
    begin
      LeftWheels[i].Rotate.X:= Angle;
      RightWheels[i].Rotate.X:= Angle;
    end;
  for i:= 0 to 6 do
    begin
      LeftTracks[i].Rotate.X:= Angle;
      LeftLinks[i].Rotate.X:= Angle;
      RightTracks[i].Rotate.X:= Angle;
      RightLinks[i].Rotate.X:= Angle;
    end;
//  сделать плавный переход между подвижными и неподвижными траками
  LeftTracks[7].Rotate.X:= Angle*2/3;
  LeftLinks[7].Rotate.X:= Angle*2/3;
  LeftTracks[8].Rotate.X:= Angle/3;
  LeftLinks[8].Rotate.X:= Angle/3;

  LeftTracks[32].Rotate.X:= Angle/3;
  LeftLinks[32].Rotate.X:= Angle/3;
  LeftTracks[33].Rotate.X:= Angle*2/3;
  LeftLinks[33].Rotate.X:= Angle*2/3;

  RightTracks[7].Rotate.X:= Angle*2/3;
  RightLinks[7].Rotate.X:= Angle*2/3;
  RightTracks[8].Rotate.X:= Angle/3;
  RightLinks[8].Rotate.X:= Angle/3;

  RightTracks[32].Rotate.X:= Angle/3;
  RightLinks[32].Rotate.X:= Angle/3;
  RightTracks[33].Rotate.X:= Angle*2/3;
  RightLinks[33].Rotate.X:= Angle*2/3;

  for i:= 34 to 73 do
    begin
      LeftTracks[i].Rotate.X:= Angle;
      LeftLinks[i].Rotate.X:= Angle;
      RightTracks[i].Rotate.X:= Angle;
      RightLinks[i].Rotate.X:= Angle;
    end;

  for i:= 0 to 6 do
    begin
      Hull[i].LocalRotate.X:= Angle * 5;        //  повернуть рычаги с левой стороны
      Hull[i+11].LocalRotate.X:= -Angle * 5;        //  повернуть рычаги с правой
      LeftWheels[i].Translate.Y:= Angle * 1.2;  //  левые колеса
 //     LeftWheels[i].LocalRotate.X:= LeftWheels[i].LocalRotate.X - Angle * 0.5;
      RightWheels[i].Translate.Y:= -Angle * 1.2;  //  правые колеса
   //   RightWheels[i].LocalRotate.X:= RightWheels[i].LocalRotate.X + Angle * 5;
    end;
end;

// поворот корпуса
procedure TurnHull(Angle: single);
var
  i: integer;
begin
// корпус
  for i:= 0 to 20 do
    Hull[i].Rotate.Z:= Angle;
 // колеса
  for i:= 0 to 10 do
    begin
      LeftWheels[i].Rotate.Z:= Angle;
      RightWheels[i].Rotate.Z:= Angle;
    end;
// гусеницы
  for i:= 0 to 73 do
    begin
      LeftTracks[i].Rotate.Z:= Angle;
      LeftLinks[i].Rotate.Z:= Angle;
      RightTracks[i].Rotate.Z:= Angle;
      RightLinks[i].Rotate.Z:= Angle;
    end;
end;

procedure Sway(A0: single; BeginTime: cardinal);
var
  A,t: single;
const
  b = 0.7;
  O = 4;
begin
  t:= (RunTime - BeginTime) / 1000;
  A:= A0 * Exp(-b * t) * cos(O * t);
  SwayHull(A);
end;

begin
  Done:= False;
  if LastTime = 0 then
    begin
      LastTime:= GetTickCount;
      StartTime:= LastTime;
      Caterpillar(LeftTracks, LeftLinks, LeftWheels);
      Caterpillar(RightTracks, RightLinks, RightWheels);
      Exit;
    end;

  t:= GetTickCount;
  RunTime:= t - StartTime; // + 30000;
  for i:= 0 to High(LeftCaterpillarStages) do
    with LeftCaterpillarStages[i] do
      begin
        if (RunTime < BeginTime) or (RunTime > BeginTime + Duration) then
          Continue;
        Speed:= BeginSpeed + (EndSpeed - BeginSpeed) * (RunTime - BeginTime) / Duration;
        shift:= (t - LastTime) / 1000 * Speed;
        Progress:= Progress + shift;
        while Progress >= 1 do
          Progress:= Progress - 1;        // Frac(Progress) дает иногда деление на 0
// задать текущее положение гусениц
        Caterpillar(LeftTracks, LeftLinks, LeftWheels);
        Caterpillar(RightTracks, RightLinks, RightWheels);
        case i of
          2: begin         // торможение после разгона
               Speed:= Speed30 - (RunTime  - BeginTime) / Duration * Speed30;
               shift:= (t - LastTime) / 1000 * Speed;
             end;
         3: begin MoveAheadLeft:= False; MoveAheadRight:= False; end;
         6: begin
              MoveAheadLeft:= True; MoveAheadRight:= False; shift:= 0;
              TankScene.GetObject('lmudguard').Visible:= True;
            end;
         7: begin MoveAheadLeft:= False; MoveAheadRight:= True; shift:= 0; end;
         8: begin MoveAheadLeft:= True; MoveAheadRight:= False; shift:= 0; end;
        end;
      end;

  for i:= 0 to High(SwayHullStages) do
    with SwayHullStages[i] do
      begin
        if (RunTime < BeginTime) or (RunTime > BeginTime + Duration) then
          Continue;
        if BeginAngle <> 999 then
          begin
            Speed:= BeginSpeed + (EndAngle - BeginAngle) * (RunTime - BeginTime) / Duration;
            SwayHull(Speed);
          end else
          Sway(EndAngle, BeginTime);
      end;

  for i:= 0 to High(LookAtStages) do
    with LookAtStages[i] do
      begin
        if (RunTime < BeginTime) or (RunTime > BeginTime + Duration) then
          Continue;
        Speed:= (RunTime - BeginTime) / Duration;
        TankScene.EyePoint:= Vector(FromPoint.X + (ToPoint.X - FromPoint.X) * Speed,
                                    FromPoint.Y + (ToPoint.Y - FromPoint.Y) * Speed,
                                    FromPoint.Z + (ToPoint.Z - FromPoint.Z) * Speed + Random / 3);
        TankScene.LookAt;
      end;

  for i:= 0 to High(TurretTurnStages) do
    with TurretTurnStages[i] do
      begin
     //   if (RunTime < BeginTime) or (RunTime > BeginTime + Duration) then
          Continue;
        Speed:= (RunTime - BeginTime) / Duration;
        for j:= 0 to 15 do                     // поворот башни
          Turret[j].Rotate.Z:= BeginAngle + (EndAngle - BeginAngle) * Speed ;
      end;

  for i:= 0 to High(HullTurnStages) do
    with HullTurnStages[i] do
      begin
        if (RunTime < BeginTime) or (RunTime > BeginTime + Duration) then
          Continue;
        Speed:= (RunTime - BeginTime) / Duration;
        TurnHull(BeginAngle + (EndAngle - BeginAngle) * Speed);   // // разворот на месте 20 градусов в секунду
      end;

  TankScene.Paint;
  LastTime:= t;
end;


procedure TForm1.FormMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
var
  o: TglObject;
begin
  if Button = mbLeft then
    begin
      LastX:= X;
      LastY:= Y;
    end;
  if (Button = mbRight) then
    begin
      o:= CurScene.GetObjectFromScreenCoord(X,Y);
      if Assigned(o) then
      Caption:= o.Name + '   ' + IntToStr(ObjectFaceNumber) + '   ' +
        IntToStr(o.Faces[ObjectFaceNumber].A) + '   ' + IntToStr(o.Faces[ObjectFaceNumber].B) + '   ' +
        IntToStr(o.Faces[ObjectFaceNumber].C) else
      Caption:= '';
    end;
end;

procedure TForm1.FormMouseMove(Sender: TObject; Shift: TShiftState; X,
  Y: Integer);
begin
// вращаем сцену
  if ssLeft in Shift then
    begin
      if ssShift in Shift then
        CurScene.Rotate(Y - LastY, X - LastX, 0) else
        CurScene.Rotate(0, Y - LastY, X - LastX);
      LastX:= X;
      LastY:= Y;
      CurScene.Paint;
    end;
end;

procedure TForm1.FormMouseWheelDown(Sender: TObject; Shift: TShiftState;
  MousePos: TPoint; var Handled: Boolean);
var
  Key: char;
begin
  Key:= '4';
  FormKeyPress(Sender, Key);
end;

procedure TForm1.FormMouseWheelUp(Sender: TObject; Shift: TShiftState;
  MousePos: TPoint; var Handled: Boolean);
var
  Key: char;
begin
  Key:= '6';
  FormKeyPress(Sender, Key);
end;

procedure TForm1.FormKeyPress(Sender: TObject; var Key: Char);
const
  StepT = 5;
begin
  with CurScene do
    case Key of
// 6,4 - перемещение вдоль оси X; 8,2 - перемещение вдоль оси Y; // '+' '-' - перемещение вдоль оси Z
      '6': Translate(-StepT, 0, 0);
      '4': Translate( StepT, 0, 0);
      '8': Translate(0, -StepT, 0);
      '2': Translate(0,  StepT, 0);
      '+': Translate(0, 0,  StepT);
      '-': Translate(0, 0, -StepT);

// масштабирование
      'Q','q': Scale( 0.1, 0, 0);
      'W','w': Scale(-0.1, 0, 0);
      'E','e': Scale(0, 0.1, 0);
      'R','r': Scale(0, -0.1, 0);
      'D','d': Scale(0, 0, 0.1);
      'F','f': Scale(0, 0, -0.1);
  end;
  CurScene.Paint;
end;

procedure TForm1.FormDestroy(Sender: TObject);
begin
 // timeKillEvent(MMTimer);
//  gluDeleteQuadric(q);
  TankScene.Free;
end;

end.
