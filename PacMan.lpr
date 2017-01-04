program PacMan;

{$MODE Delphi}

uses
  Forms, Interfaces,
  fPacMan in 'fPacMan.pas' {frmPacman};

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TfrmPacman, frmPacman);
  Application.Run;
end.
