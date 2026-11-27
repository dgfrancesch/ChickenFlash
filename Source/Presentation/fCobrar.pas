unit fCobrar;

// Pantalla de cobro (ruta #/cobrar). Lee la venta armada en el dashboard desde
// sessionStorage ('venta'), deja elegir la forma de pago (o venta a deuda) y al
// confirmar la guarda en la base de datos y muestra el resumen.
// Las tasas salen de elToque (uTasas); las monedas fijadas a mano en Ajustes usan
// la tasa del usuario. Al abrir se usa la última guardada y se consulta elToque;
// si responde, se actualiza la pantalla; si no, se queda la guardada.

interface

uses
  System.SysUtils, System.Classes, JS, Web, WEBLib.Graphics, WEBLib.Controls,
  WEBLib.Forms, WEBLib.Dialogs, Vcl.StdCtrls, WEBLib.StdCtrls, WEBLib.WebCtrls,
  Vcl.Controls;

type
  TForm6 = class(TWebForm)
    cbForm: TWebHTMLDiv;
    cbDone: TWebHTMLDiv;
    cbTotal: TWebHTMLDiv;
    cbStatus: TWebHTMLDiv;
    cb: TWebHTMLDiv;
    cbDoneTxt: TWebLabel;
    cbTrf: TWebEdit;
    cbChCup: TWebEdit;
    cbNet: TWebHTMLSpan;
    cbChgSeg: TWebHTMLDiv;
    cbAllCash: TWebButton;
    cbAllTrf: TWebButton;
    cbFx: TWebEdit;
    cbMsg: TWebHTMLDiv;
    cbBack: TWebButton;
    cbChFxL: TWebHTMLSpan;
    cbChg: TWebHTMLDiv;
    cbOk: TWebButton;
    cbChFx: TWebEdit;
    cbCash: TWebEdit;
    cbMlc: TWebEdit;
    cbAgain: TWebButton;
    cbBrk: TWebHTMLDiv;
    cbFxSeg: TWebHTMLDiv;
    cbRates: TWebHTMLSpan;
    btnCancelNew: TWebButton;
    cbDejar: TWebCheckBox;
    buscaDeudor: TWebEdit;
    newTel: TWebEdit;
    newNombre: TWebEdit;
    newBox: TWebHTMLDiv;
    cbKeep: TWebLabel;
    cbPagoSec: TWebHTMLDiv;
    btnSaveNew: TWebButton;
    cbADeuda: TWebCheckBox;
    newNota: TWebEdit;
    btnToggleNew: TWebButton;
    dList: TWebHTMLDiv;
    cbDeudorSel: TWebHTMLDiv;
    cbDebtBox: TWebLabel;
    procedure WebFormCreate(Sender: TObject);
  private
    [async]
    procedure ActualizarTasas;
  public
  end;

var
  Form6: TForm6;

implementation

uses
  uShell, uTasas, uVentasService, uDeudasService;

{$R *.dfm}

function Por(const Id: string): TJSElement;
begin
  Result := document.getElementById(Id);
end;

// Texto que se muestra junto a las tasas
function EstadoDe(T: TTasasCup): string;
begin
  if T.Origen = 'toque' then
    Result := 'actualizada ' + T.Hora
  else if T.Origen = 'guardada' then
    Result := 'sin conexión, guardada de las ' + T.Hora
  else
    Result := 'SIN CONEXIÓN: tasa de ejemplo, no es real';
end;

// Deja las tasas listas para cuando se abra la pantalla (la primera vez)
procedure PonerTasas(ValUsd, ValEur, ValMlc: Double; ManUsd, ManEur, ManMlc: Boolean;
  const Estado: string; Aviso: Boolean);
begin
  asm
    window.CFTasas = { USD: ValUsd, EUR: ValEur, MLC: ValMlc,
      man: { USD: ManUsd, EUR: ManEur, MLC: ManMlc }, estado: Estado, aviso: Aviso };
  end;
end;

// Cambia las tasas con la pantalla ya abierta y recalcula todo
procedure AplicarTasas(ValUsd, ValEur, ValMlc: Double; ManUsd, ManEur, ManMlc: Boolean;
  const Estado: string; Aviso: Boolean);
begin
  asm
    if (window.CFCobro) {
      window.CFCobro.tasas({ USD: ValUsd, EUR: ValEur, MLC: ValMlc,
        man: { USD: ManUsd, EUR: ManEur, MLC: ManMlc } }, Estado, Aviso);
    }
  end;
end;

type
  TGuardarFn = procedure(const Json: string; Cb: TJSFunction);
  TCargarFn = procedure(Cb: TJSFunction);
    TCrearFn = procedure(const Nombre, Tel, Nota: string; Cb: TJSFunction);

// ---------- Venta normal ----------
[async]
procedure GuardarInterno(const Json: string; Cb: TJSFunction);
var
  R: TResultadoVenta;
  Ok: Boolean;
  Err: string;
begin
  try
    R := await(TResultadoVenta, TVentasService.RegistrarVenta(Json));
    Ok := R.Ok;
    Err := R.Error;
  except
    Ok := False;
    Err := 'No se pudo guardar la venta. Intenta de nuevo.';
  end;
  asm
    Cb(Ok, Err);
  end;
end;

procedure GuardarPuente(const Json: string; Cb: TJSFunction);
begin
  GuardarInterno(Json, Cb);   // llamar a una async desde una no async es válido
end;


[async]
procedure CargarDeudoresInterno(Cb: TJSFunction);
var
  R: TResultadoDeudas;
  Ok: Boolean;
  Js, Err: string;
begin
  try
    R := await(TResultadoDeudas, TDeudasService.Cargar);
    Ok := R.Ok;
    Js := R.Json;
    Err := R.Error;
  except
    Ok := False;
    Js := '[]';
    Err := 'No se pudieron cargar los deudores.';
  end;
  asm
    Cb(Ok, Js, Err);
  end;
end;

procedure CargarDeudoresPuente(Cb: TJSFunction);
begin
  CargarDeudoresInterno(Cb);
end;

[async]
procedure CrearDeudorInterno(const Nombre, Tel, Nota: string; Cb: TJSFunction);
var
  R: TResultadoDeudor;
  Ok: Boolean;
  Id: Integer;
  Err: string;
begin
  try
    R := await(TResultadoDeudor, TDeudasService.Crear(Nombre, Tel, Nota));
    Ok := R.Ok;
    Id := R.Id;
    Err := R.Error;
  except
    Ok := False;
    Id := 0;
    Err := 'No se pudo crear el deudor. Intenta de nuevo.';
  end;
  asm
    Cb(Ok, Id, Err);
  end;
end;

procedure CrearDeudorPuente(const Nombre, Tel, Nota: string; Cb: TJSFunction);
begin
  CrearDeudorInterno(Nombre, Tel, Nota, Cb);
end;

procedure PonerGuardar;
var
  Fn: TGuardarFn;
  FnDeudores: TCargarFn;
  FnCrear: TCrearFn;
begin
  Fn := @GuardarPuente;
  FnDeudores := @CargarDeudoresPuente;
  FnCrear := @CrearDeudorPuente;
  asm
    window.CFGuardar = Fn;
    window.CFDeudores = FnDeudores;
    window.CFCrearDeudor = FnCrear;
  end;
end;

// Toda la logica de la pantalla esta en JavaScript dentro de un asm.
// Toda la logica de la pantalla esta en JavaScript dentro de un asm.
procedure InstalarCobro;
begin
  asm
    (function () {
      // Puede haber otro #cb (el del dashboard, que aun no se libera): se usa el ultimo,
      // que es el de esta pantalla, y todo se busca solo dentro de el.
      var todos = document.querySelectorAll('[id="cb"]');
      var root = todos.length ? todos[todos.length - 1] : null;
      if (!root) { return; }

      var g = function (id) { return root.querySelector('[id="' + id + '"]'); };
      var TOTAL = 0, VENTA = null;
      var R = { USD: 400, EUR: 430, MLC: 280 };
      var MAN = { USD: false, EUR: false, MLC: false };
      var fxC = 'USD', chC = 'CUP', man = null, dejar = false, guardando = false;
      var aDeuda = false, deudores = [], deudor = null, cargados = false;

      var n = function (id) {
        var v = parseFloat(String(g(id).value).replace(',', '.'));
        return isNaN(v) || v < 0 ? 0 : v;
      };
      var f = function (x, d) {
        d = d || 0;
        return x.toLocaleString('es', { minimumFractionDigits: d, maximumFractionDigits: d }).replace(/\u00a0|\u202f/g, ' ');
      };
      // Monto en CUP tal cual (hasta 2 decimales, sin redondear a entero): 116.4 se ve 116,4
      var fa = function (x) {
        return x.toLocaleString('es', { minimumFractionDigits: 0, maximumFractionDigits: 2 }).replace(/\u00a0|\u202f/g, ' ');
      };
      var fl = function (x, d) { return Math.floor(x * Math.pow(10, d) + 1e-9) / Math.pow(10, d); };
      var r2 = function (x) { return Math.round(x * 100) / 100; };
      var sel = function (seg, c) {
        var bs = g(seg).querySelectorAll('button');
        for (var i = 0; i < bs.length; i++) {
          bs[i].classList.toggle('sel', bs[i].getAttribute('data-c') === c);
        }
      };

      // Linea de tasas: de donde sale cada una (elToque o manual de Ajustes) y de cuando
      // son (en naranja si no son recientes)
      var rotulo = function (estado, aviso) {
        var s = function (k) { return MAN[k] ? 'manual' : 'elToque'; };
        g('cbRates').innerHTML = '1 USD = ' + R.USD + ' CUP (' + s('USD') + ') \u00b7 1 EUR = ' + R.EUR +
          ' CUP (' + s('EUR') + ') \u00b7 1 MLC = ' + R.MLC + ' CUP (' + s('MLC') + ')<br>elToque: ' + estado +
          ' \u00b7 <a href="#/ajustes" style="color:var(--cb-gold);text-decoration:underline">Cambiar en Ajustes</a>';
        g('cbRates').style.color = aviso ? 'var(--cb-warn)' : '';
      };

      var calc = function () {
        var cash = n('cbCash'), fx = n('cbFx'), trf = n('cbTrf'), mlc = n('cbMlc');
        var fxCup = Math.round(fx * R[fxC] * 100) / 100, mlcCup = Math.round(mlc * R.MLC * 100) / 100;
        var sc = cash + fxCup, st = trf + mlcCup, paid = sc + st;
        return { cash: cash, fx: fx, trf: trf, mlc: mlc, fxCup: fxCup, mlcCup: mlcCup, sc: sc, st: st, paid: paid, diff: Math.round((paid - TOTAL) * 100) / 100 };
      };
      var totalText = function (diff) {
        if (chC === 'CUP' || !calc().fx) { return fa(diff) + ' CUP'; }
        return f(fl(diff / R[chC], 2), 2) + ' ' + chC;
      };
      // Reparto del vuelto en divisa + CUP.
      // Automatico: divisa en unidades enteras y el resto en CUP exacto (116.4).
      // Si escribes la divisa: el CUP se recalcula. Si escribes el CUP: la divisa NO cambia
      // y puedes dar menos (la diferencia es lo que no se entrega).
      var getSplit = function (diff) {
        var r = R[chC], fx, cup, tope = fl(diff / r, 2);
        if (man && man.field === 'fx') { fx = r2(Math.min(man.v, tope)); cup = diff - fx * r; }
        else if (man) { fx = r2(Math.min(man.fx, tope)); cup = Math.min(man.v, diff - fx * r); }
        else { fx = Math.floor(diff / r + 1e-9); cup = diff - fx * r; }
        return { fx: fx, cup: Math.max(0, r2(cup)) };
      };
      var changeText = function (diff) {
        if (chC === 'CUP' || !calc().fx) { return fa(diff) + ' CUP'; }
        var sp = getSplit(diff), P = [];
        if (sp.fx > 0) { P.push(f(sp.fx, sp.fx % 1 ? 2 : 0) + ' ' + chC); }
        if (sp.cup > 0) { P.push(fa(sp.cup) + ' CUP'); }
        return P.length ? P.join(' + ') : '0 CUP';
      };
      var fillSplit = function (which) {
        var d = calc().diff, sp = getSplit(d);
        if (which !== 'fx') { g('cbChFx').value = sp.fx ? String(sp.fx) : ''; }
        if (which !== 'cup') { g('cbChCup').value = sp.cup ? String(sp.cup) : ''; }
        var over = false, r = R[chC];
        if (man && man.field === 'fx') { over = man.v * r > d + 0.01; }
        else if (man) { over = man.v > d - sp.fx * r + 0.01; }
        g('cbChgAmt').textContent = over
          ? 'No puedes devolver m\u00e1s del vuelto total (' + totalText(d) + ')'
          : 'Vuelto total: ' + totalText(d) + ' = ' + fa(d) + ' CUP';
      };

      var upd = function () {
        man = null;
        var c = calc();
        g('cbFxEq').textContent = c.fx
          ? f(c.fx, 2) + ' ' + fxC + ' \u00d7 ' + R[fxC] + ' = ' + fa(c.fxCup) + ' CUP'
          : '1 ' + fxC + ' = ' + R[fxC] + ' CUP';
        g('cbMlcEq').textContent = c.mlc
          ? f(c.mlc, 2) + ' MLC \u00d7 ' + R.MLC + ' = ' + fa(c.mlcCup) + ' CUP'
          : 'Cuenta como transferencia';
        g('cbSumCash').textContent = fa(c.sc) + ' CUP';
        g('cbSumTrf').textContent = fa(c.st) + ' CUP';
        var fill = g('cbFill'), s = g('cbStatus');
        fill.style.width = Math.min(100, TOTAL > 0 ? c.paid / TOTAL * 100 : 0) + '%';
        var hayVuelto = !aDeuda && c.diff > 0.005;
        if (!hayVuelto) { dejar = false; g('cbDejar').checked = false; }
        g('cbKeep').classList.toggle('cb-hide', !hayVuelto);
        g('cbDejarAmt').textContent = '(' + fa(c.diff) + ' CUP)';
        var showChg = hayVuelto && c.fx > 0 && !dejar;
        if (!(hayVuelto && c.fx > 0) && chC !== 'CUP') { chC = 'CUP'; sel('cbChgSeg', 'CUP'); }
        if (aDeuda) {
          if (c.diff >= -0.005) {
            fill.style.background = 'var(--cb-warn)'; s.style.color = 'var(--cb-warn)';
            s.textContent = 'El pago cubre el total: desmarca venta a deuda';
          } else {
            fill.style.background = 'var(--cb-gold)'; s.style.color = 'var(--cb-gold)';
            s.textContent = 'Queda a deuda: ' + fa(-c.diff) + ' CUP';
          }
        } else if (c.diff < -0.005) {
          fill.style.background = 'var(--cb-warn)'; s.style.color = 'var(--cb-warn)';
          s.textContent = 'Faltan ' + fa(-c.diff) + ' CUP';
        } else if (c.diff <= 0.005) {
          fill.style.background = 'var(--cb-ok)'; s.style.color = 'var(--cb-ok)';
          s.textContent = 'Pago completo';
        } else if (dejar) {
          fill.style.background = 'var(--cb-ok)'; s.style.color = 'var(--cb-ok)';
          s.textContent = 'Vuelto dejado: ' + fa(c.diff) + ' CUP (ganancia)';
        } else {
          fill.style.background = 'var(--cb-gold)'; s.style.color = 'var(--cb-gold)';
          s.textContent = 'Vuelto: ' + totalText(c.diff);
        }
        g('cbChg').classList.toggle('cb-hide', !showChg);
        if (showChg) {
          g('cbBrk').classList.toggle('cb-hide', chC === 'CUP');
          g('cbChFxL').textContent = 'Entregas en ' + chC;
          fillSplit();
        }
        g('cbMsg').textContent = '';
      };

      var setAll = function (id) {
        var ids = ['cbCash', 'cbFx', 'cbTrf', 'cbMlc'];
        for (var i = 0; i < ids.length; i++) { g(ids[i]).value = ''; }
        g(id).value = TOTAL;
        upd();
      };

      // ---------- Venta a deuda ----------
      var setBtn = function () {
        var b = g('cbOk');
        b.lastChild.textContent = aDeuda ? 'Registrar venta a deuda' : 'Confirmar venta';
      };

      var pintar = function () {
        var q = String(g('buscaDeudor').value || '').trim().toLowerCase();
        var l = g('dList');
        l.innerHTML = '';
        deudores.forEach(function (d) {
          if (q && String(d.nombre || '').toLowerCase().indexOf(q) < 0) { return; }
          var b = document.createElement('button');
          b.type = 'button';
          b.className = 'd-item' + (deudor && !deudor.nuevo && deudor.id === d.id ? ' sel' : '');
          b.setAttribute('data-id', d.id);
          var s = document.createElement('b');
          s.textContent = d.nombre;
          var t = document.createElement('small');
          var saldo = d.saldo_cup != null ? d.saldo_cup : d.saldo;
          t.textContent = (d.nota ? d.nota + ' \u00b7 ' : '') + 'Debe ' + fa(Number(saldo || 0)) + ' CUP';
          b.appendChild(s); b.appendChild(t);
          l.appendChild(b);
        });
        if (!l.children.length) { l.textContent = cargados ? 'Sin resultados' : 'Cargando...'; }
        var sl = g('cbDeudorSel');
        sl.textContent = deudor ? 'Deudor: ' + deudor.nombre + (deudor.nuevo ? ' (nuevo)' : '') : '';
      };

      var cargarDeudores = function () {
        if (cargados) { pintar(); return; }
        pintar();
        window.CFDeudores(function (ok, json, error) {
          if (!ok) { g('cbMsg').textContent = error || 'No se pudieron cargar los deudores.'; return; }
          try { deudores = JSON.parse(json) || []; } catch (e) { deudores = []; }
          cargados = true;
          pintar();
        });
      };

      var setDeuda = function (v) {
        aDeuda = v;
        g('cbQuick').classList.toggle('cb-hide', v);
        g('cbDeuda').classList.toggle('cb-hide', !v);
        setBtn();
        upd();
        if (v) { cargarDeudores(); }
      };

      var mostrarHechoDeuda = function (c) {
        var L = [['Total', '<b>' + fa(TOTAL) + ' CUP</b>']];
        if (c.paid > 0.005) { L.push(['Abono inicial', '<b>' + fa(c.paid) + ' CUP</b>']); }
        L.push(['Queda a deuda', '<b>' + fa(-c.diff) + ' CUP</b>']);
        g('cbDoneTxt').innerHTML = L.map(function (x) { return x[0] + ': ' + x[1]; }).join('<br>') +
          '<br>Deudor: <b id="cbDoneDeudor"></b>';
        g('cbDoneTxt').querySelector('#cbDoneDeudor').textContent = deudor.nombre;
        try { sessionStorage.removeItem('venta'); } catch (e) { }
        g('cbMsg').textContent = '';
        g('cbForm').classList.add('cb-hide');
        g('cbDone').classList.remove('cb-hide');
        root.scrollTop = 0;
      };

      var abrir = function () {
        var v = null;
        try { v = JSON.parse(sessionStorage.getItem('venta') || 'null'); } catch (e) { v = null; }
        if (!v || !v.items || !v.items.length) { return false; }
        VENTA = v;
        // Id de la venta: se genera una sola vez, asi un reintento no la duplica
        if (!VENTA.uid) {
          VENTA.uid = (window.crypto && crypto.randomUUID) ? crypto.randomUUID()
            : 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function (ch) {
                var r = Math.random() * 16 | 0;
                return (ch === 'x' ? r : (r & 3 | 8)).toString(16);
              });
          try { sessionStorage.setItem('venta', JSON.stringify(VENTA)); } catch (e) { }
        }
        TOTAL = r2(Number(v.total));
        var t = window.CFTasas || R;
        R = { USD: Number(t.USD), EUR: Number(t.EUR), MLC: Number(t.MLC) };
        MAN = t.man || MAN;

        g('cbTotal').textContent = f(TOTAL, TOTAL % 1 ? 2 : 0) + ' CUP';
        var partes = [];
        for (var i = 0; i < v.items.length; i++) {
          var it = v.items[i];
          partes.push(it.nombre + ' \u00d7' + it.cantidad + (it.unidad === 'lb' ? ' lb' : ''));
        }
        g('cbItems').textContent = partes.join(' \u00b7 ');
        rotulo(t.estado || 'consultando...', !!t.aviso);
        g('cbNet').textContent = navigator.onLine ? 'En l\u00ednea' : 'Sin conexi\u00f3n';
        g('cbNet').style.color = navigator.onLine ? '' : 'var(--cb-warn)';
        dejar = false; g('cbDejar').checked = false;
        aDeuda = false; g('cbADeuda').checked = false;
        sel('cbFxSeg', 'USD'); sel('cbChgSeg', 'CUP');
        upd();
        setBtn();
        root.classList.add('cb-open');
        root.scrollTop = 0;
        return true;
      };

      // Pagos tal como entraron, restando el vuelto entregado (orden: efectivo, divisa, transf., MLC)
      var armarPagos = function (c) {
        var b = [
          { m: 'efectivo',      mo: 'CUP', cup: c.cash,   tasa: 1,      raw: c.cash },
          { m: 'exterior',      mo: fxC,   cup: c.fxCup,  tasa: R[fxC], raw: c.fx },
          { m: 'transferencia', mo: 'CUP', cup: c.trf,    tasa: 1,      raw: c.trf },
          { m: 'exterior',      mo: 'MLC', cup: c.mlcCup, tasa: R.MLC,  raw: c.mlc }
        ];
        var d = (!dejar && c.diff > 0.005) ? c.diff : 0;
        var out = [];
        b.forEach(function (x) {
          var q = Math.min(x.cup, d);
          d = r2(d - q);
          var rest = r2(x.cup - q);
          if (rest <= 0.004) { return; }
          var monto = q === 0 ? x.raw : (x.tasa === 1 ? rest : Math.round(rest / x.tasa * 10000) / 10000);
          out.push({ metodo: x.m, moneda: x.mo, monto: monto, tasa_cup: x.tasa });
        });
        return out;
      };

      var mostrarHecho = function (c) {
        var L = [['Total', '<b>' + fa(TOTAL) + ' CUP</b>']];
        if (c.cash) { L.push(['Efectivo (CUP)', '<b>' + fa(c.cash) + ' CUP</b>']); }
        if (c.fx) { L.push(['Divisa en efectivo', '<b>' + f(c.fx, 2) + ' ' + fxC + '</b> (' + fa(c.fxCup) + ' CUP)']); }
        if (c.trf) { L.push(['Transferencia (CUP)', '<b>' + fa(c.trf) + ' CUP</b>']); }
        if (c.mlc) { L.push(['MLC (transferencia)', '<b>' + f(c.mlc, 2) + ' MLC</b> (' + fa(c.mlcCup) + ' CUP)']); }
        if (c.diff > 0.005) {
          if (dejar) { L.push(['Vuelto dejado (ganancia)', '<b>' + fa(c.diff) + ' CUP</b>']); }
          else { L.push(['Vuelto entregado', '<b>' + changeText(c.diff) + '</b>']); }
        }
        g('cbDoneTxt').innerHTML = L.map(function (x) { return x[0] + ': ' + x[1]; }).join('<br>');
        try { sessionStorage.removeItem('venta'); } catch (e) { }
        g('cbMsg').textContent = '';
        g('cbForm').classList.add('cb-hide');
        g('cbDone').classList.remove('cb-hide');
        root.scrollTop = 0;
      };

      var confirmar = function () {
        if (guardando) { return; }
        var c = calc();
        if (!aDeuda && c.diff < -0.005) {
          g('cbMsg').textContent = 'A\u00fan faltan ' + fa(-c.diff) + ' CUP para completar el pago.';
          return;
        }
        if (aDeuda && !deudor) {
          g('cbMsg').textContent = 'Elige o crea un deudor.';
          return;
        }
        if (aDeuda && c.diff >= -0.005) {
          g('cbMsg').textContent = 'El pago cubre el total. Desmarca "Venta a deuda" o baja el abono.';
          return;
        }
        var items = [], falta = false;
        for (var i = 0; i < VENTA.items.length; i++) {
          var it = VENTA.items[i];
          var pid = it.producto_id || it.id;
          var pr = it.precio_cup != null ? it.precio_cup : it.precio;
          if (!pid || pr == null) { falta = true; break; }
          var o = { producto_id: Number(pid), nombre: it.nombre,
                    cantidad: Number(it.cantidad), precio_cup: Number(pr) };
          if (it.jaba_id != null) { o.jaba_id = Number(it.jaba_id); }
          items.push(o);
        }
        if (falta) {
          g('cbMsg').textContent = 'Faltan producto_id o precio en la venta. Hay que guardarlos desde el dashboard.';
          return;
        }
        guardando = true;
        g('cbOk').disabled = true;
        g('cbMsg').textContent = 'Guardando...';

        var pl = { id: VENTA.uid, total_cup: TOTAL, items: items, pagos: armarPagos(c) };
        if (aDeuda) {
          if (deudor.nuevo) {
            pl.deudor_nuevo = { nombre: deudor.nombre, telefono: deudor.telefono || '', nota: deudor.nota || '' };
          } else {
            pl.deudor_id = Number(deudor.id);
          }
        }
        window.CFGuardar(JSON.stringify(pl), function (ok, error) {
          guardando = false;
          g('cbOk').disabled = false;
          if (!ok) { g('cbMsg').textContent = error || 'No se pudo guardar la venta.'; return; }
          if (aDeuda) { mostrarHechoDeuda(c); } else { mostrarHecho(c); }
        });
      };

      root.addEventListener('click', function (e) {
        var b = e.target && e.target.closest ? e.target.closest('button') : null;
        if (!b) { return; }
        var id = b.id, pid = b.parentNode ? b.parentNode.id : '';
        if (id === 'cbBack' || id === 'cbAgain') { window.location.hash = '/vender'; }
        else if (id === 'cbAllCash') { setAll('cbCash'); }
        else if (id === 'cbAllTrf') { setAll('cbTrf'); }
        else if (id === 'cbOk') { confirmar(); }
        else if (id === 'btnToggleNew') { g('newBox').classList.toggle('cb-hide'); }
        else if (id === 'btnCancelNew') { g('newBox').classList.add('cb-hide'); }
        else if (id === 'btnSaveNew') {
          var nom = String(g('newNombre').value).trim();
          if (!nom) { g('cbMsg').textContent = 'Escribe el nombre del deudor.'; return; }
          deudor = { nuevo: true, nombre: nom,
                     telefono: String(g('newTel').value).trim(),
                     nota: String(g('newNota').value).trim() };
          g('newBox').classList.add('cb-hide');
          g('cbMsg').textContent = '';
          pintar();
        }
        else if (pid === 'dList') {
          var sid = b.getAttribute('data-id');
          deudor = deudores.filter(function (x) { return String(x.id) === sid; })[0] || null;
          g('cbMsg').textContent = '';
          pintar();
        }
        else if (pid === 'cbFxSeg') { fxC = b.getAttribute('data-c'); sel('cbFxSeg', fxC); upd(); }
        else if (pid === 'cbChgSeg') { chC = b.getAttribute('data-c'); sel('cbChgSeg', chC); upd(); }
      });

      root.addEventListener('change', function (e) {
        if (!e.target) { return; }
        if (e.target.id === 'cbDejar') { dejar = !!e.target.checked; upd(); }
        else if (e.target.id === 'cbADeuda') { setDeuda(!!e.target.checked); }
      });

      root.addEventListener('input', function (e) {
        var id = e.target ? e.target.id : '';
        if (id === 'buscaDeudor') { pintar(); return; }
        if (id === 'cbCash' || id === 'cbFx' || id === 'cbTrf' || id === 'cbMlc') { upd(); }
        else if (id === 'cbChFx') { man = { field: 'fx', v: n('cbChFx') }; fillSplit('fx'); }
        else if (id === 'cbChCup') { man = { field: 'cup', v: n('cbChCup'), fx: n('cbChFx') }; fillSplit('cup'); }
      });

      // Para que Pascal cambie las tasas cuando elToque responde (no si la venta ya se confirmo)
      window.CFCobro = {
        tasas: function (t, estado, aviso) {
          if (!g('cbDone').classList.contains('cb-hide')) { return; }
          R = { USD: Number(t.USD), EUR: Number(t.EUR), MLC: Number(t.MLC) };
          MAN = t.man || MAN;
          rotulo(estado, aviso);
          upd();
        }
      };

      if (!abrir()) { window.location.hash = '/vender'; return; }

      // Que no quede el foco en ningun campo (en el telefono abriria el teclado solo).
      // Se repite un par de veces porque el formulario puede enfocar un edit al terminar de crearse.
      var sinFoco = function () {
        var a = document.activeElement;
        if (a && a !== document.body && a.blur) { a.blur(); }
      };
      sinFoco();
      setTimeout(sinFoco, 0);
      setTimeout(sinFoco, 200);
    })();
  end;
end;

procedure TForm6.WebFormCreate(Sender: TObject);
var
  T: TTasasCup;
  Estado: string;
begin
  TShell.Actual := Self;
  TShell.Activar('vender');                    // la barra inferior sigue marcando Vender

  // La pantalla abre ya con la última tasa guardada; elToque se consulta detrás
  T := TTasas.Guardada;
  if T.Origen = 'ejemplo' then
    Estado := 'sin tasa guardada, consultando...'
  else
    Estado := 'consultando...';
  PonerTasas(T.EfUsd, T.EfEur, T.EfMlc, T.ManUsd, T.ManEur, T.ManMlc, Estado, T.Origen = 'ejemplo');
  PonerGuardar;                                // incluye los puentes de deuda y deudores
  InstalarCobro;
  ActualizarTasas;
end;

procedure TForm6.ActualizarTasas;
var
  T: TTasasCup;
begin
  T := await(TTasasCup, TTasas.Consultar);
  if TShell.Actual <> Self then Exit;          // ya saliste de esta pantalla
  AplicarTasas(T.EfUsd, T.EfEur, T.EfMlc, T.ManUsd, T.ManEur, T.ManMlc, EstadoDe(T), T.Origen <> 'toque');
end;

end.
