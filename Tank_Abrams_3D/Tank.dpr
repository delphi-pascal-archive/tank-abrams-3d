program Tank;

uses
  Forms,
  Main in 'Main.pas' {Form1},
  aiOGL in 'aiOGL.pas';

{$R *.RES}

begin
  Application.Initialize;
  Application.CreateForm(TForm1, Form1);
  Application.Run;
end.
