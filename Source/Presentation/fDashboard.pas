unit fDashboard;

interface

uses
  System.SysUtils, System.Classes, JS, Web, WEBLib.Graphics, WEBLib.Controls,
  WEBLib.Forms, WEBLib.Dialogs, Vcl.StdCtrls, WEBLib.StdCtrls, Vcl.Controls,
  WEBLib.WebCtrls;

type
  TForm2 = class(TWebForm)
    btnMenuAjustes: TWebButton;
    lblInicial: TWebHTMLDiv;
    divVenta: TWebHTMLDiv;
    divProductos: TWebHTMLDiv;
    btnSalir: TWebButton;
    lblRed: TWebHTMLSpan;
    divFiltros: TWebHTMLDiv;
    dashboard: TWebHTMLDiv;
    btnCerrarPanel: TWebButton;
    btnCobrar: TWebButton;
    lblInicialPanel: TWebHTMLDiv;
    btnMenuHistorial: TWebButton;
    btnMenuReportes: TWebButton;
    btnNavCaja: TWebButton;
    btnMenuCompras: TWebButton;
    btnVaciar: TWebButton;
    btnNavVender: TWebButton;
    btnMenuTasas: TWebButton;
    lblVentaAviso: TWebLabel;
    btnNavMas: TWebButton;
    btnNavInventario: TWebButton;
    panelLateral: TWebHTMLDiv;
    edtBuscar: TWebEdit;
    btnFondoPanel: TWebButton;
    procedure WebFormCreate(Sender: TObject);
    procedure AbrirPanel;
    procedure CerrarPanel;
    procedure btnNavMasClick(Sender: TObject);
    procedure btnCerrarPanelClick(Sender: TObject);
    procedure btnFondoPanelClick(Sender: TObject);
      [async]
    procedure btnSalirClick(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  Form2: TForm2;

implementation

uses
uSession, uAuthService, uPie, fLogin;

{$R *.dfm}

procedure TForm2.AbrirPanel;
begin
  document.getElementById('panelLateral').classList.add('abierto');
end;

procedure TForm2.btnCerrarPanelClick(Sender: TObject);
begin
  CerrarPanel;
end;

procedure TForm2.btnFondoPanelClick(Sender: TObject);
begin
   CerrarPanel;
end;

procedure TForm2.btnNavMasClick(Sender: TObject);
begin
  AbrirPanel;
end;

procedure TForm2.btnSalirClick(Sender: TObject);
begin
  btnSalir.Enabled := False;
  await(Boolean, TAuthService.Logout);
  window.location.reload(False);
end;

procedure TForm2.CerrarPanel;
begin
  document.getElementById('panelLateral').classList.remove('abierto');
end;

procedure TForm2.WebFormCreate(Sender: TObject);
var
  Nombre, Inicial: string;
begin
  Nombre := TSession.UserName;
  Inicial := UpperCase(Copy(Nombre, 1, 1));
  document.getElementById('lblSaludo').innerHTML := 'Hola, ' + Nombre;
  document.getElementById('lblNombrePanel').innerHTML := Nombre;
  document.getElementById('lblInicialPanel').innerHTML := Inicial;
  lblInicial.ElementHandle.innerHTML := Inicial;
  PonerPie('pieDashboard');
end;

end.