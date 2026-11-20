program ChickenFlash;

{$R *.dres}

uses
  Vcl.Forms,
  WEBLib.Forms,
  uAuthService in 'Source\Domain\Services\uAuthService.pas',
  fLogin in 'Source\Presentation\fLogin.pas' {Form1: TWebForm} {*.html},
  uConfig in 'Source\Infraestructure\uConfig.pas',
  uHttp in 'Source\Infraestructure\uHttp.pas',
  uSession in 'Source\Infraestructure\uSession.pas',
  fDashboard in 'Source\Presentation\fDashboard.pas' {Form2: TWebForm} {*.html},
  uPie in 'Source\Presentation\uPie.pas',
  fInventory in 'Source\Presentation\fInventory.pas' {Form3: TWebForm} {*.html},
  uShell in 'Source\Presentation\uShell.pas',
  uNavegacion in 'Source\Presentation\uNavegacion.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  if TAuthService.HaySesion then
  begin
    TNavegacion.Iniciar;                       // barra y panel, porque ya hay sesión
    Application.CreateForm(TForm2, Form2);
  end
  else
    Application.CreateForm(TForm1, Form1);
  Application.Run;
end.
