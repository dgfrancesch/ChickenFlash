unit fConteo;

interface

uses
  System.SysUtils, System.Classes, JS, Web, WEBLib.Graphics, WEBLib.Controls,
  WEBLib.Forms, WEBLib.Dialogs, WEBLib.WebCtrls, Vcl.Controls, Vcl.StdCtrls,
  WEBLib.StdCtrls;

type
  TForm10 = class(TWebForm)
    cvBtnDenoms: TWebButton;
    cvCant: TWebHTMLSpan;
    lblInicial: TWebHTMLDiv;
    cvGrid: TWebHTMLDiv;
    cvList: TWebHTMLDiv;
    cvRoot: TWebHTMLDiv;
    procedure WebFormCreate(Sender: TObject);
  end;

var
  Form10: TForm10;

implementation

{$R *.dfm}

uses
  uShell, uNavegacion;

const
  N_DEN = 13;
  DENOMS: array[0..12] of Integer =
    (1, 5, 10, 20, 50, 100, 200, 500, 1000, 2000, 5000, 10000, 20000);
  VISIBLES_INI = '0,0,1,1,1,1,1,1,1,0,0,0,0';   // 10, 20, 50, 100, 200, 500 y 1000

var
  GVis: array[0..12] of Boolean;
  GCant: array[0..12] of Integer;

{ ---------- utilidades ---------- }

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

function Fmt(N: Double): string;
begin
  asm
    Result = Math.round(N).toLocaleString('en-US').replace(/,/g, ' ');
  end;
end;

function Confirmar(const Msg: string): Boolean;
begin
  asm
    Result = window.confirm(Msg);
  end;
end;

function NumeroDe(E: TJSElement): Double;
begin
  asm
    var n = parseFloat(E.value);
    Result = isNaN(n) ? 0 : n;
  end;
end;

function Parte(const S: string; I: Integer): string;
begin
  asm
    var p = String(S).split(',');
    Result = (I < p.length) ? p[I] : '';
  end;
end;

// Se guarda con el prefijo cfaj_: "Borrar datos guardados" de Ajustes también lo limpia
function Leer(const Clave, Defecto: string): string;
begin
  asm
    try {
      var v = localStorage.getItem('cfaj_' + Clave);
      Result = (v !== null) ? v : Defecto;
    } catch (e) { Result = Defecto; }
  end;
end;

procedure Escribir(const Clave, Valor: string);
begin
  asm
    try { localStorage.setItem('cfaj_' + Clave, Valor); } catch (e) {}
  end;
end;

function IdxDe(Den: Integer): Integer;
var
  i: Integer;
begin
  Result := -1;
  for i := 0 to N_DEN - 1 do
    if DENOMS[i] = Den then
    begin
      Result := i;
      Exit;
    end;
end;

{ ---------- estado ---------- }

procedure CargarEstado;
var
  i: Integer;
  C, V: string;
begin
  C := Leer('conteo_c', '');
  V := Leer('conteo_v', VISIBLES_INI);
  for i := 0 to N_DEN - 1 do
  begin
    GCant[i] := StrToIntDef(Parte(C, i), 0);
    if GCant[i] < 0 then GCant[i] := 0;
    GVis[i] := Parte(V, i) = '1';
  end;
end;

procedure GuardarEstado;
var
  i: Integer;
  C, V: string;
begin
  C := '';
  V := '';
  for i := 0 to N_DEN - 1 do
  begin
    if i > 0 then
    begin
      C := C + ',';
      V := V + ',';
    end;
    C := C + IntToStr(GCant[i]);
    if GVis[i] then V := V + '1' else V := V + '0';
  end;
  Escribir('conteo_c', C);
  Escribir('conteo_v', V);
end;

{ ---------- pintar ---------- }

procedure ActualizarResumen;
var
  i, Cant: Integer;
  Total: Double;
begin
  Total := 0;
  Cant := 0;
  for i := 0 to N_DEN - 1 do
    if GVis[i] then
    begin
      Total := Total + DENOMS[i] * GCant[i];
      Cant := Cant + GCant[i];
    end;
  El('cvTotal').innerHTML := Fmt(Total) + ' CUP';
  if Cant = 1 then
    El('cvCant').innerHTML := '1 billete en caja'
  else
    El('cvCant').innerHTML := IntToStr(Cant) + ' billetes en caja';
end;

procedure PintarChips;
var
  i: Integer;
  H, Cl: string;
begin
  H := '';
  for i := 0 to N_DEN - 1 do
  begin
    if GVis[i] then Cl := 'cv-chip on' else Cl := 'cv-chip';
    H := H + '<button type="button" class="' + Cl + '" data-cv="chip" data-d="' +
      IntToStr(DENOMS[i]) + '">' + Fmt(DENOMS[i]) + '</button>';
  end;
  El('cvGrid').innerHTML := H;
end;

function SubTexto(Idx: Integer): string;
var
  Etq, Cl: string;
begin
  if GCant[Idx] = 1 then Etq := 'billete' else Etq := 'billetes';
  if GCant[Idx] = 0 then Cl := 'zero' else Cl := '';
  Result := '<span>' + IntToStr(GCant[Idx]) + ' ' + Etq + ' × ' + Fmt(DENOMS[Idx]) + '</span>' +
    '<b class="' + Cl + '">' + Fmt(DENOMS[Idx] * GCant[Idx]) + ' CUP</b>';
end;

procedure PintarBilletes;
var
  i, N: Integer;
  H, Act: string;
begin
  H := '';
  N := 0;
  for i := 0 to N_DEN - 1 do
  begin
    if not GVis[i] then Continue;
    Inc(N);
    if GCant[i] > 0 then Act := ' active' else Act := '';
    H := H +
      '<div class="cv-bill" data-d="' + IntToStr(DENOMS[i]) + '">' +
        '<div class="cv-bill-top">' +
          '<div class="cv-bill-val">' +
            '<span class="cv-badge' + Act + '">' + Fmt(DENOMS[i]) + '</span>' +
            '<span class="cv-bill-lbl">Billete de ' + Fmt(DENOMS[i]) + '</span>' +
          '</div>' +
          '<div class="cv-stepper">' +
            '<button type="button" class="cv-step" data-cv="paso" data-op="-1" aria-label="Restar 1 billete de ' + IntToStr(DENOMS[i]) + '">−</button>' +
            '<input type="number" inputmode="numeric" min="0" class="cv-inp" value="' + IntToStr(GCant[i]) + '" aria-label="Cantidad de billetes de ' + IntToStr(DENOMS[i]) + '">' +
            '<button type="button" class="cv-step" data-cv="paso" data-op="1" aria-label="Sumar 1 billete de ' + IntToStr(DENOMS[i]) + '">+</button>' +
          '</div>' +
        '</div>' +
        '<div class="cv-bill-sub">' + SubTexto(i) + '</div>' +
      '</div>';
  end;
  if N = 0 then
    H := '<div class="cv-empty">Activa al menos una denominación arriba para empezar a contar.</div>';
  El('cvList').innerHTML := H;
  ActualizarResumen;
end;

// Actualiza una sola tarjeta (así el cuadro no pierde el foco al escribir)
procedure RefrescarTarjeta(Card: TJSElement; Idx: Integer; PonerInput: Boolean);
var
  C: Integer;
  Texto: string;
begin
  C := GCant[Idx];
  Texto := SubTexto(Idx);
  asm
    var b = Card.querySelector('.cv-badge');
    if (b) b.classList.toggle('active', C > 0);
    var s = Card.querySelector('.cv-bill-sub');
    if (s) s.innerHTML = Texto;
    if (PonerInput) {
      var i = Card.querySelector('.cv-inp');
      if (i) i.value = C;
    }
  end;
  ActualizarResumen;
end;

{ ---------- eventos ---------- }

function AlClic(Event: TJSEvent): Boolean;
var
  B, Card: TJSElement;
  Acc: string;
  i, Idx, Op: Integer;
begin
  Result := True;
  B := Cerca(TJSElement(Event.target), '[data-cv]');
  if B = nil then Exit;
  Acc := string(B.getAttribute('data-cv'));

  if Acc = 'atras' then
  begin
    if window.history.length > 1 then
      window.history.back
    else
      window.location.hash := '/vender';
  end
  else if Acc = 'denoms' then
  begin
    asm
      var p = document.getElementById('cvCfg');
      var b = document.getElementById('cvBtnDenoms');
      var abrir = p.hidden;
      p.hidden = !abrir;
      b.classList.toggle('on', abrir);
      b.setAttribute('aria-expanded', abrir ? 'true' : 'false');
    end;
  end
  else if Acc = 'limpiar' then
  begin
    if Confirmar('¿Poner todos los billetes en 0?') then
    begin
      for i := 0 to N_DEN - 1 do
        GCant[i] := 0;
      GuardarEstado;
      PintarBilletes;
    end;
  end
  else if Acc = 'chip' then
  begin
    Idx := IdxDe(StrToIntDef(string(B.getAttribute('data-d')), 0));
    if Idx >= 0 then
    begin
      GVis[Idx] := not GVis[Idx];
      GuardarEstado;
      PintarChips;
      PintarBilletes;
    end;
  end
  else if Acc = 'paso' then
  begin
    Card := Cerca(B, '.cv-bill');
    if Card = nil then Exit;
    Idx := IdxDe(StrToIntDef(string(Card.getAttribute('data-d')), 0));
    if Idx < 0 then Exit;
    Op := StrToIntDef(string(B.getAttribute('data-op')), 0);
    GCant[Idx] := GCant[Idx] + Op;
    if GCant[Idx] < 0 then GCant[Idx] := 0;
    GuardarEstado;
    RefrescarTarjeta(Card, Idx, True);
  end;
end;

// Cantidad escrita a mano
function AlEntrada(Event: TJSEvent): Boolean;
var
  Inp, Card: TJSElement;
  Idx: Integer;
  V: Double;
begin
  Result := True;
  Inp := Cerca(TJSElement(Event.target), '.cv-inp');
  if Inp = nil then Exit;
  Card := Cerca(Inp, '.cv-bill');
  if Card = nil then Exit;
  Idx := IdxDe(StrToIntDef(string(Card.getAttribute('data-d')), 0));
  if Idx < 0 then Exit;
  V := NumeroDe(Inp);
  if V < 0 then V := 0;
  if V > 999999 then V := 999999;
  GCant[Idx] := Trunc(V);
  GuardarEstado;
  RefrescarTarjeta(Card, Idx, False);
end;

// Al tocar el cuadro se selecciona todo para escribir encima
function AlEnfocar(Event: TJSEvent): Boolean;
begin
  Result := True;
  asm
    var t = Event.target;
    if (t && t.classList && t.classList.contains('cv-inp')) t.select();
  end;
end;

{ ---------- pantalla ---------- }

procedure TForm10.WebFormCreate(Sender: TObject);
begin
  TNavegacion.Registrar(Self);
  TShell.Activar('mas');                 // marca "Más" en el menú inferior

  CargarEstado;
  PintarChips;
  PintarBilletes;

  El('cvRoot').addEventListener('click', @AlClic);
  El('cvRoot').addEventListener('input', @AlEntrada);
  El('cvRoot').addEventListener('focusin', @AlEnfocar);
end;

end.
