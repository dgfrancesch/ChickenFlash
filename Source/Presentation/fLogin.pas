unit fLogin;

interface

uses
  System.SysUtils, System.Classes, JS, Web, WEBLib.Graphics, WEBLib.Controls,
  WEBLib.Forms, WEBLib.Dialogs, Vcl.Controls, Vcl.StdCtrls, WEBLib.StdCtrls;

type
  TForm1 = class(TWebForm)
    edtUsuario: TWebEdit;
    edtClave: TWebEdit;
    btnEntrar: TWebButton;
    lblError: TWebLabel;
    [async]
    procedure btnEntrarClick(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  Form1: TForm1;

implementation

{$R *.dfm}

uses
  uAuthService;

procedure TForm1.btnEntrarClick(Sender: TObject);
var
  R: TAuthResult;
begin
  lblError.Caption := '';
  btnEntrar.Enabled := False;

  R := await(TAuthResult, TAuthService.Login(edtUsuario.Text, edtClave.Text));

  btnEntrar.Enabled := True;
  if R.Ok then
    lblError.Caption := 'Entró bien'   // aquí luego abrimos la pantalla principal
  else
    lblError.Caption := R.Mensaje;
end;

end.
