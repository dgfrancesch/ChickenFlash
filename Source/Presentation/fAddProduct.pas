unit fAddProduct;

interface

uses
  System.SysUtils, System.Classes, JS, Web, WEBLib.Graphics, WEBLib.Controls,
  WEBLib.Forms, WEBLib.Dialogs, WEBLib.StdCtrls, Vcl.Controls, WEBLib.ExtCtrls,
  Vcl.StdCtrls, WEBLib.WebCtrls;

type
  TForm4 = class(TWebForm)
    lblUnidad: TWebHTMLSpan;
    divSeccion: TWebHTMLDiv;
    lblGuardar: TWebHTMLSpan;
    btnAddCancelar: TWebButton;
    lblRed: TWebHTMLSpan;
    edtDetalle: TWebEdit;
    imgFoto: TWebImageControl;
    btnUniLb: TWebButton;
    edtPrecio: TWebSpinEdit;
    divAgregar: TWebHTMLDiv;
    btnAddGuardar: TWebButton;
    divFotoPrev: TWebHTMLDiv;
    divHints: TWebHTMLDiv;
    lblError: TWebHTMLDiv;
    edtStock: TWebSpinEdit;
    edtNombre: TWebEdit;
    divToast: TWebHTMLDiv;
    btnUniPaq: TWebButton;
    btnCambiarFoto: TWebButton;
    btnVisible: TWebButton;
    lblToast: TWebHTMLSpan;
    btnQuitarFoto: TWebButton;
    btnFoto: TWebButton;
    btnAddVolver: TWebButton;
    procedure WebFormCreate(Sender: TObject);
    procedure btnAddCancelarClick(Sender: TObject);
    procedure btnAddVolverClick(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  Form4: TForm4;

implementation

uses
uShell,uNavegacion;

{$R *.dfm}

procedure TForm4.btnAddCancelarClick(Sender: TObject);
begin
     TNavegacion.IrARuta('inventario');
end;


procedure TForm4.btnAddVolverClick(Sender: TObject);
begin
 TNavegacion.IrARuta('inventario');
end;

procedure TForm4.WebFormCreate(Sender: TObject);
begin
  TShell.Activar('inventario');   // la barra inferior sigue marcando Inventario
  TShell.Actual := Self;
end;

end.