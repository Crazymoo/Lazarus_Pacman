program PacMan;

{$MODE Delphi}

uses
  Forms, Interfaces,
  fPacMan in 'fPacMan.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TfrmPacman, frmPacman);
  Application.Run;
end.
