unit fLogin;

interface

uses
  System.SysUtils, System.Classes, JS, Web, WEBLib.Graphics, WEBLib.Controls,
  WEBLib.Forms, WEBLib.Dialogs, Vcl.Controls, Vcl.StdCtrls, WEBLib.StdCtrls,
  WEBLib.ExtCtrls, DateUtils;

type
  TForm1 = class(TWebForm)
    lnkOlvide: TWebLinkLabel;
    titulo: TWebLabel;
    edtClave: TWebEdit;
    lblError: TWebLabel;
    btnCrear: TWebButton;
    btnEntrar: TWebButton;
    btnVer: TWebButton;
    edtUsuario: TWebEdit;
    [async]
    procedure btnEntrarClick(Sender: TObject);
    procedure btnVerClick(Sender: TObject);
    procedure WebFormCreate(Sender: TObject);
  private
    procedure AbrirDashboard;
  public
  end;

var
  Form1: TForm1;

implementation

{$R *.dfm}

uses
  uAuthService, fDashboard,uShell,uNavegacion;

procedure TForm1.btnVerClick(Sender: TObject);
begin
  if edtClave.ElementHandle.getAttribute('type') = 'password' then
    edtClave.ElementHandle.setAttribute('type', 'text')
  else
    edtClave.ElementHandle.setAttribute('type', 'password');
end;

procedure TForm1.WebFormCreate(Sender: TObject);
begin
  document.getElementById('footer').innerHTML :=
    '&copy; ' + IntToStr(YearOf(Now)) + ' Chicken Flash • Sistema de Punto de Venta e Inventario';
end;

procedure TForm1.AbrirDashboard;
begin
  TNavegacion.Registrar(Self);   // el login es la pantalla actual y será liberada
  TNavegacion.Iniciar;
  TNavegacion.IrA(TForm2);
end;

procedure TForm1.btnEntrarClick(Sender: TObject);
var
  R: TAuthResult;
begin
  lblError.Caption := '';
  btnEntrar.Enabled := False;
  try
    R := await(TAuthResult, TAuthService.Login(edtUsuario.Text, edtClave.Text));
  finally
    btnEntrar.Enabled := True;
  end;

  if R.Ok then
    AbrirDashboard
  else
    lblError.Caption := R.Mensaje;
end;

end.
