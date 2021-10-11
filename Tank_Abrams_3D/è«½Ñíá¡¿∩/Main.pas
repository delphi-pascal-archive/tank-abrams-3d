unit Main;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs, aiOGL, OpenGL,
  ExtCtrls, StdCtrls;

type

  TMyScene = class(TglScene)
    procedure Draw; override;
  end;

  TForm1 = class(TForm)
    Panel1: TPanel;
    Button1: TButton;
    Label1: TLabel;
    Edit1: TEdit;
    Label2: TLabel;
    Edit2: TEdit;
    Label3: TLabel;
    Edit3: TEdit;
    procedure FormCreate(Sender: TObject);
    procedure Button1Click(Sender: TObject);
    procedure Edit1Change(Sender: TObject);
    procedure Edit2Change(Sender: TObject);
    procedure Edit3Change(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
  private
    MyScene: TMyScene;
    q: GLUquadricObj;
    Swaying: boolean;
    procedure Idle(Sender: TObject; var Done: Boolean);
  public
    { Public declarations }
  end;

var
  Form1: TForm1;
  StartTime: TDateTime;
  CurGr: single;                 // текущее положение маятника
  CyclicFrequency: single;       // циклическая частота собственных колебаний,т.е.
                                 //   число колебаний за 2 * pi секунд
  AttenuationConstant: single;   // коэффициент затухания
  StartingAngle: single;         // начальный угол

implementation

{$R *.DFM}

procedure TMyScene.Draw;
begin
  inherited;
  glPushMatrix();
  glTranslatef(0, 8, 0);
  gluCylinder(Form1.q, 0.1, 0.1, 1, 20, 20);   // ось маятника
  glPopMatrix();

  glPushMatrix();
  glTranslatef(0, 8, 0.5);
  gluSphere(Form1.q, 0.2, 20, 20);          // крепление маятника к оси
  glPopMatrix();

  glPushMatrix();
  glTranslatef(0, 8, 0.5);
  glRotatef(90, 1, 0, 0);
  glRotatef(CurGr, 0, 1, 0);
  gluCylinder(Form1.q, 0.1, 0.1, 12, 20, 20);   // маятник
  glPopMatrix();


  glPushMatrix();
  glTranslatef(0, 8, -0.5);
  glRotatef(CurGr, 0, 0, 1);
  glTranslatef(0, -12, 1);
  gluSphere(Form1.q, 0.5, 20, 20);
  glPopMatrix();
end;

procedure TForm1.FormCreate(Sender: TObject);
begin
  Swaying:= False;
  MyScene:= TMySCene.Create(Self);
  MyScene.AddObject(CreatePlane(Vector(-10, 10, 0), Vector(10, 10, 0), Vector(10, -10, 0), Vector(-10, -10, 0)));

  MyScene.EyePoint:= Vector(-3, 0, 10);
  MyScene.LookAt;
  MyScene.Lighting.Enabled[0]:= True;
  MyScene.Lighting.Position[0]:= Vector(10, 0, 10);

  q:= gluNewQuadric;

  MyScene.GetNormals;
  MyScene.Render;
  MyScene.Paint;

  Edit1Change(nil);
  Edit2Change(nil);
  Edit3Change(nil);
    
  Application.OnIdle:= Idle;
end;

procedure Sway;
var
  t: single;
begin
  t:= (GetTickCount - StartTime) / 1000;
  CurGr:= StartingAngle * Exp(-AttenuationConstant * t) * cos(CyclicFrequency * t);
end;

procedure TForm1.Idle(Sender: TObject; var Done: Boolean);
begin
  Done:= False;
  if Swaying then
    begin
      Sway;
      MyScene.Paint;
    end;
end;


procedure TForm1.Button1Click(Sender: TObject);
begin
  StartTime:= GetTickCount;
  Swaying:= not Swaying;
  if Swaying then
    Button1.Caption:= 'Stop' else
    Button1.Caption:= 'Start';
end;

procedure TForm1.Edit1Change(Sender: TObject);
begin
  if Swaying then
    Button1.Click;
  try
    CyclicFrequency:= StrToFloat(Edit1.Text);
  except
    CyclicFrequency:= 4;
  end;

end;

procedure TForm1.Edit2Change(Sender: TObject);
begin
  if Swaying then
    Button1.Click;
  try
    AttenuationConstant:= StrToFloat(Edit2.Text);
  except
    AttenuationConstant:= 0.5;
  end;
end;

procedure TForm1.Edit3Change(Sender: TObject);
begin
  if Swaying then
    Button1.Click;
  try
    CurGr:= StrToFloat(Edit3.Text);
    StartingAngle:= CurGr;
    MyScene.Paint;
  except
    StartingAngle:= 90;
  end;
end;

procedure TForm1.FormDestroy(Sender: TObject);
begin
  gluDeleteQuadric(q);
end;

end.

