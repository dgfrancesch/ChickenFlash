unit fAjustes;

interface

uses
  System.SysUtils, System.Classes, JS, Web, WEBLib.Graphics, WEBLib.Controls,
  WEBLib.Forms, WEBLib.Dialogs, WEBLib.WebCtrls, WEBLib.StdCtrls, Vcl.StdCtrls,
  Vcl.Controls;

type
  TForm8 = class(TWebForm)
    ajRoot: TWebHTMLDiv;
    ajceur: TWebButton;
    ajTema: TWebHTMLDiv;
    ajManual: TWebHTMLDiv;
    lblInicial: TWebHTMLDiv;
    ajStock: TWebSpinEdit;
    ajBoxToque: TWebHTMLSpan;
    ajToast: TWebHTMLDiv;
    ajmusd: TWebSpinEdit;
    ajToastTxt: TWebHTMLSpan;
    ajcusd: TWebButton;
    ajChkToque: TWebButton;
    ajmmlc: TWebSpinEdit;
    ajcmlc: TWebButton;
    ajBase: TWebHTMLDiv;
    ajmeur: TWebSpinEdit;
    procedure WebFormCreate(Sender: TObject);
  end;

var
  Form8: TForm8;

implementation

{$R *.dfm}

uses
  uShell, uNavegacion, uAjustes, uTasas, uHttp;

var
  GTimer: NativeInt;

function El(const Id: string): TJSElement;
begin
  Result := document.getElementById(Id);
end;

function Cerca(E: TJSElement; const Selector: string): TJSElement;
begin
  asm
    Result = E.closest(Selector);
  end;
end;

function EsChange(Event: TJSEvent): Boolean;
begin
  asm
    Result = (Event.type === 'change');
  end;
end;

function LeerNumero(const Id: string): Double;
begin
  asm
    var e = document.getElementById(Id);
    var n = e ? parseFloat(e.value) : NaN;
    Result = isNaN(n) ? 0 : n;
  end;
end;

procedure PonerValor(const Id: string; V: Double);
begin
  asm
    var e = document.getElementById(Id);
    if (e) e.value = (V > 0) ? V : '';
  end;
end;

procedure PonerDeshabilitado(const Id: string; Valor: Boolean);
begin
  asm
    var e = document.getElementById(Id);
    if (e) e.disabled = Valor;
  end;
end;

procedure PonerCheck(const Id: string; Activo: Boolean);
begin
  asm
    var e = document.getElementById(Id);
    if (e) { e.classList.toggle('on', Activo); e.setAttribute('aria-checked', Activo ? 'true' : 'false'); }
  end;
end;

procedure MarcarSeg(const ContId, Valor: string);
begin
  asm
    var c = document.getElementById(ContId);
    if (c) c.querySelectorAll('button').forEach(function (b) {
      b.classList.toggle('on', b.getAttribute('data-v') === Valor);
    });
  end;
end;

function Confirmar(const Msg: string): Boolean;
begin
  asm
    Result = window.confirm(Msg);
  end;
end;

procedure Aviso(const Msg: string);
begin
  El('ajToastTxt').innerHTML := Msg;
  El('ajToast').removeAttribute('hidden');
  window.clearTimeout(GTimer);
  GTimer := window.setTimeout(
    procedure
    begin
      if El('ajToast') <> nil then
        El('ajToast').setAttribute('hidden', '');
    end, 2200);
end;

procedure RefrescarMoneda(const Mon: string);
var
  Act: Boolean;
begin
  Act := TAjustes.MonedaActiva(Mon);
  PonerCheck('ajc-' + Mon, Act);
  PonerValor('ajm-' + Mon, TAjustes.TasaManual(Mon));
  PonerDeshabilitado('ajm-' + Mon, not Act);
end;

procedure Refrescar;
begin
  MarcarSeg('ajTema', TAjustes.Tema);
  MarcarSeg('ajBase', TAjustes.MonedaBase);
  PonerCheck('ajBoxToque', TAjustes.UsarToque);
  PonerCheck('ajChkToque', TAjustes.UsarToque);
  if TAjustes.UsarToque then
    El('ajManual').setAttribute('hidden', '')
  else
    El('ajManual').removeAttribute('hidden');
  RefrescarMoneda('usd');
  RefrescarMoneda('eur');
  RefrescarMoneda('mlc');
end;

function AlClic(Event: TJSEvent): Boolean;
var
  B: TJSElement;
  Acc, Val: string;
  Nuevo: Boolean;
  G: TTasasCup;
begin
  Result := True;
  B := Cerca(TJSElement(Event.target), '[data-aj]');
  if B = nil then Exit;
  Acc := string(B.getAttribute('data-aj'));
  Val := string(B.getAttribute('data-v'));

  if Acc = 'tema' then
  begin
    TAjustes.PonerTema(Val);
    TAjustes.Aplicar;
    Refrescar;
    if Val = 'light' then Aviso('Modo claro activado') else Aviso('Modo oscuro activado');
  end
  else if Acc = 'toque' then
  begin
    Nuevo := not TAjustes.UsarToque;
    if not Nuevo then
    begin
      // pasa a manual: si no hay tasa definida, parte de la última real
      G := TTasas.Guardada;
      if TAjustes.TasaManual('usd') <= 0 then TAjustes.PonerTasaManual('usd', G.Usd);
      if TAjustes.TasaManual('eur') <= 0 then TAjustes.PonerTasaManual('eur', G.Eur);
      if TAjustes.TasaManual('mlc') <= 0 then TAjustes.PonerTasaManual('mlc', G.Mlc);
    end;
    TAjustes.PonerUsarToque(Nuevo);
    Refrescar;
    if Nuevo then Aviso('Usando tasas de elToque') else Aviso('Modo de tasas manual');
  end
    else if Acc = 'act' then
  begin
    TAjustes.PonerMonedaActiva(Val, not TAjustes.MonedaActiva(Val));
    Refrescar;
  end
  else if Acc = 'base' then
  begin
    TAjustes.PonerMonedaBase(Val);
    Refrescar;
    Aviso('Moneda predeterminada: ' + UpperCase(Val));
  end
  else if Acc = 'limpiar' then
  begin
    if Confirmar('¿Borrar los datos guardados en este dispositivo?') then
    begin
      THttp.LimpiarCache;
      Aviso('Datos guardados borrados');
    end;
  end
  else if Acc = 'salir' then
  begin
    TShell.CerrarSesion;
  end
    else if Acc = 'atras' then
  begin
    if window.history.length > 1 then
      window.history.back
    else
      window.location.hash := '/vender';
  end
end;

// 'input' guarda en silencio; 'change' (al soltar el campo) guarda y avisa
function AlEntrada(Event: TJSEvent): Boolean;
var
  Id: string;
  V: Double;
  Final: Boolean;
begin
  Result := True;
  Id := string(TJSElement(Event.target).id);
   Final := EsChange(Event);
  V := LeerNumero(Id);

  if Copy(Id, 1, 4) = 'ajm-' then
  begin
    if V > 0 then
    begin
      TAjustes.PonerTasaManual(Copy(Id, 5, 3), V);
      if Final then Aviso('Tasa manual guardada');
    end;
  end
  else if Id = 'ajStock' then
  begin
    if V >= 1 then
    begin
      TAjustes.PonerLimiteStock(Trunc(V));
      if Final then Aviso('Aviso de stock bajo: ' + IntToStr(Trunc(V)));
    end;
  end;
end;

procedure TForm8.WebFormCreate(Sender: TObject);
begin
  TNavegacion.Registrar(Self);
  TShell.Activar('mas');

  PonerValor('ajStock', TAjustes.LimiteStock);
  Refrescar;

  El('ajRoot').addEventListener('click', @AlClic);
  El('ajRoot').addEventListener('input', @AlEntrada);
  El('ajRoot').addEventListener('change', @AlEntrada);
end;

end.
