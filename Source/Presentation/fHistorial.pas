unit fHistorial;

interface

uses
  System.SysUtils, System.Classes, JS, Web, WEBLib.Graphics, WEBLib.Controls,
  WEBLib.Forms, WEBLib.Dialogs, WEBLib.WebCtrls, Vcl.StdCtrls, WEBLib.StdCtrls,
  Vcl.Controls;

type
  TForm9 = class(TWebForm)
    hvList: TWebHTMLDiv;
    hvRoot: TWebHTMLDiv;
    lblInicial: TWebHTMLDiv;
    hvBusca: TWebEdit;
    hvChips: TWebHTMLDiv;
    procedure WebFormCreate(Sender: TObject);
  end;

var
  Form9: TForm9;

implementation

{$R *.dfm}

uses
  uShell, uNavegacion, uHttp, uSession;

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

procedure IniciarEstado;
begin
  asm
    window.__hv = { f: 'hoy', t: '', open: null, ventas: [], seq: 0,
                    cargando: true, error: false, cache: '',
                    perf: {}, perfOk: false };
  end;
end;

function FiltroActual: string;
begin
  asm
    Result = window.__hv.f;
  end;
end;

function SeqActual: Integer;
begin
  asm
    Result = window.__hv.seq;
  end;
end;

function SiguienteSeq: Integer;
begin
  asm
    window.__hv.seq++;
    Result = window.__hv.seq;
  end;
end;

function PerfilesListos: Boolean;
begin
  asm
    Result = window.__hv.perfOk;
  end;
end;

procedure PonerPerfiles(const Body: string);
begin
  asm
    var m = {};
    try {
      JSON.parse(Body).forEach(function (p) { m[p.id] = p.nombre; });
      window.__hv.perfOk = true;
    } catch (e) {}
    window.__hv.perf = m;
  end;
end;

// "hoy" y "ayer" se filtran en el servidor; efectivo/transfer se filtran en el cliente
function Ruta(const Filtro: string): string;
begin
  asm
    var q = '/rest/v1/ventas?select=id,fecha,total_cup,estado,nota,usuario_id,' +
            'venta_items(nombre,cantidad,subtotal_cup),' +
            'pagos(metodo,moneda,monto,monto_cup)' +
            '&order=fecha.desc&limit=500';
    var hoy = new Date(); hoy.setHours(0, 0, 0, 0);
    if (Filtro === 'hoy') {
      q += '&fecha=gte.' + hoy.toISOString();
    } else if (Filtro === 'ayer') {
      var ayer = new Date(hoy); ayer.setDate(ayer.getDate() - 1);
      q += '&fecha=gte.' + ayer.toISOString() + '&fecha=lt.' + hoy.toISOString();
    }
    Result = q;
  end;
end;

procedure PonerDatos(const Body: string; Ok: Boolean; const Cache: string);
begin
  asm
    var h = window.__hv;
    h.error = !Ok;
    h.cache = Cache;
    h.cargando = false;
    try { h.ventas = Ok ? JSON.parse(Body) : []; } catch (e) { h.ventas = []; h.error = true; }
  end;
end;

procedure Pintar;
begin
  asm
    var h = window.__hv;
    var $ = function (id) { return document.getElementById(id); };
    var fmt = function (n) {
      return Math.round(Number(n) || 0).toLocaleString("en-US").split(",").join(" ");
    };
    var esc = function (s) {
      var x = String(s == null ? "" : s);
      x = x.split("&").join("&amp;");
      x = x.split("<").join("&lt;");
      x = x.split(">").join("&gt;");
      x = x.split(String.fromCharCode(34)).join("&quot;");
      return x;
    };
    var hora = function (f) {
      if (!f) return "";
      return new Date(f).toLocaleTimeString([], { hour: "2-digit", minute: "2-digit", hour12: false });
    };
    var linea = function (i) {
      var c = Number(i.cantidad);
      return (isNaN(c) ? "" : c + " ") + (i.nombre || "");
    };
    var num = function (v) { return String(v.id).slice(0, 4).toUpperCase(); };
    var anulada = function (v) { return String(v.estado || "").toLowerCase().indexOf("anul") >= 0; };
    var tipo = function (p) {
      return String(p.metodo || "").toLowerCase().indexOf("transf") >= 0 ? "transfer" : "efectivo";
    };
    var etiqueta = function (p) {
      var mon = String(p.moneda || "CUP").toUpperCase();
      if (mon !== "CUP") return { t: mon + " (" + Number(p.monto) + " $)", c: " usd" };
      return tipo(p) === "transfer"
        ? { t: "Transferencia", c: " tr" }
        : { t: "Efectivo CUP", c: "" };
    };

    var t = h.t.trim().toLowerCase();
    var lista = h.ventas.filter(function (v) {
      var pagos = v.pagos || [];
      if ((h.f === "efectivo" || h.f === "transfer") &&
          !pagos.some(function (p) { return tipo(p) === h.f; })) return false;
      if (!t) return true;
      if (num(v).toLowerCase().indexOf(t) >= 0) return true;
      return (v.venta_items || []).some(function (i) {
        return linea(i).toLowerCase().indexOf(t) >= 0;
      });
    });

    var suma = lista.reduce(function (s, v) {
      return anulada(v) ? s : s + (Number(v.total_cup) || 0);
    }, 0);
    $("hvSum").textContent = fmt(suma) + " CUP";
    $("hvCnt").textContent = lista.length + (lista.length === 1 ? " venta" : " ventas");

    document.querySelectorAll("#hvChips button").forEach(function (b) {
      b.classList.toggle("on", b.getAttribute("data-v") === h.f);
    });

    var html = "";
    if (h.cargando) {
      html = `<div class="hv-empty">Cargando…</div>`;
    } else if (h.error) {
      html = `<div class="hv-empty">No se pudo cargar el historial.</div>`;
    } else if (!lista.length) {
      html = `<div class="hv-empty">No hay ventas en este filtro.</div>`;
    } else {
      if (h.cache) {
        html += `<div class="hv-cache">Sin conexión · datos guardados a las ${esc(h.cache)}</div>`;
      }
      html += lista.map(function (v) {
        var abierta = h.open === v.id;
        var items = v.venta_items || [];
        var tags = (v.pagos || []).map(function (p) {
          var e = etiqueta(p);
          return `<span class="hv-tag${e.c}">${esc(e.t)}</span>`;
        }).join("");
        if (anulada(v)) tags += `<span class="hv-tag anu">Anulada</span>`;
        var quien = h.perf[v.usuario_id] || "";
        var s = `<article class="hv-sale">` +
          `<button class="hv-head" type="button" data-hv="abrir" data-id="${esc(v.id)}">` +
            `<div class="hv-id"><b>#${esc(num(v))}</b>${tags}</div>` +
            `<span class="hv-tot">${fmt(v.total_cup)} CUP</span>` +
          `</button>` +
          `<div class="hv-sub"><span>${hora(v.fecha)}${quien ? " · " + esc(quien) : ""}</span>` +
                   `<button class="hv-more" type="button" data-hv="abrir" data-id="${esc(v.id)}">${abierta ? "Ocultar detalle" : "Ver detalle"}</button></div>`;
        if (abierta) {
          s += `<div class="hv-items">` + items.map(function (i) {
            return `<div class="hv-line"><span>${esc(linea(i))}</span><span>${fmt(i.subtotal_cup)} CUP</span></div>`;
          }).join("");
          if (v.nota) s += `<div class="hv-line"><span>Nota: ${esc(v.nota)}</span></div>`;
          s += `</div>`;
        } else {
          s += `<div class="hv-sub hv-res">` + items.map(function (i) { return esc(linea(i)); }).join(" · ") + `</div>`;
        }
        return s + `</article>`;
      }).join("");
    }
    $("hvList").innerHTML = html;
  end;
end;

[async]
procedure Cargar;
var
  R, RP: TApiResponse;
  Mi: Integer;
begin
  Mi := SiguienteSeq;
  asm
    window.__hv.cargando = true;
  end;
  Pintar;

  // nombres de los admins: se piden una sola vez
  if not PerfilesListos then
  begin
    RP := await(TApiResponse, THttp.Send('GET', '/rest/v1/perfiles?select=id,nombre', '', TSession.Token));
    if RP.Ok then
      PonerPerfiles(RP.Body);
  end;

  R := await(TApiResponse, THttp.Send('GET', Ruta(FiltroActual), '', TSession.Token));

  if Mi <> SeqActual then Exit; // llegó tarde: el usuario ya cambió de filtro

  if R.DeCache then
    PonerDatos(R.Body, R.Ok, R.CacheHora)
  else
    PonerDatos(R.Body, R.Ok, '');
  Pintar;
end;

function AlClic(Event: TJSEvent): Boolean;
var
  B: TJSElement;
  Acc, Val: string;
begin
  Result := True;
  B := Cerca(TJSElement(Event.target), '[data-hv]');
  if B = nil then Exit;
  Acc := string(B.getAttribute('data-hv'));
  Val := string(B.getAttribute('data-v'));

  if Acc = 'filtro' then
  begin
    asm
      window.__hv.f = Val;
      window.__hv.open = null;
    end;
    Cargar;
  end
  else if Acc = 'abrir' then
  begin
    asm
      var id = B.getAttribute('data-id');
      window.__hv.open = (window.__hv.open === id) ? null : id;
    end;
    Pintar;
  end
  else if Acc = 'atras' then
  begin
    if window.history.length > 1 then
      window.history.back
    else
      window.location.hash := '/vender';
  end;
end;

function AlBuscar(Event: TJSEvent): Boolean;
begin
  Result := True;
  asm
    window.__hv.t = Event.target.value;
  end;
  Pintar;
end;

procedure TForm9.WebFormCreate(Sender: TObject);
begin
  TNavegacion.Registrar(Self);
  TShell.Activar('mas');

  IniciarEstado;
  El('hvRoot').addEventListener('click', @AlClic);
  El('hvBusca').addEventListener('input', @AlBuscar);
  Cargar; // por defecto: filtro "Hoy"
end;

end.
