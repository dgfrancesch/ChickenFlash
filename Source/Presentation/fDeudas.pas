unit fDeudas;

// Pantalla de deudas (ruta #/deudas). Lista los deudores con sus deudas, el detalle
// (productos y abonos) y permite abonar o pagar completo con pagar_deuda.
// Pascal solo hace de puente con la BD (uDeudasService) y con las tasas (uTasas);
// la pantalla vive en JavaScript dentro de un asm, igual que fCobrar.

interface

uses
  System.SysUtils, System.Classes, JS, Web, WEBLib.Graphics, WEBLib.Controls,
  WEBLib.Forms, WEBLib.Dialogs, Vcl.Controls, Vcl.StdCtrls, WEBLib.StdCtrls,
  WEBLib.WebCtrls;

type
  TForm11 = class(TWebForm)
    ddList: TWebHTMLDiv;
    ddChips: TWebHTMLDiv;
    ddDetClose: TWebButton;
    ddDetItems: TWebHTMLDiv;
    ddPayClose: TWebButton;
    ddPayStat: TWebHTMLDiv;
    ddNet: TWebHTMLSpan;
    ddCash: TWebEdit;
    ddAllCash: TWebButton;
    ddDetAb: TWebButton;
    ddFx: TWebEdit;
    ddPayOk: TWebButton;
    ddDoneTit: TWebLabel;
    dd: TWebHTMLDiv;
    ddTrf: TWebEdit;
    ddBack: TWebButton;
    ddPayView: TWebHTMLDiv;
    ddDetPays: TWebHTMLDiv;
    ddDetFull: TWebButton;
    ddAviso: TWebHTMLDiv;
    ddBusca: TWebEdit;
    ddMlc: TWebEdit;
    ddMain: TWebHTMLDiv;
    ddPayMsg: TWebHTMLDiv;
    ddDetActs: TWebHTMLDiv;
    ddPayDone: TWebHTMLDiv;
    ddDoneBack: TWebButton;
    ddAllTrf: TWebButton;
    ddPayForm: TWebHTMLDiv;
    ddFxSeg: TWebHTMLDiv;
    ddDetail: TWebHTMLDiv;
    ddRates: TWebHTMLSpan;
    ddDoneTxt: TWebLabel;
    procedure WebFormCreate(Sender: TObject);
  private
    [async]
    procedure ActualizarTasas;
  public
  end;

var
  Form11: TForm11;

implementation

uses
  uShell, uNavegacion, uTasas, uDeudasService;

{$R *.dfm}

// ---- Tasas (se usa la última guardada y elToque actualiza detrás) ----

// Texto que se muestra junto a las tasas (igual que en Cobrar)
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
procedure PonerTasasD(ValUsd, ValEur, ValMlc: Double; ManUsd, ManEur, ManMlc: Boolean;
  const Estado: string; Aviso: Boolean);
begin
  asm
    window.CFDTasas = { USD: ValUsd, EUR: ValEur, MLC: ValMlc,
      man: { USD: ManUsd, EUR: ManEur, MLC: ManMlc }, estado: Estado, aviso: Aviso };
  end;
end;

// Cambia las tasas con la pantalla ya abierta y recalcula todo
procedure AplicarTasasD(ValUsd, ValEur, ValMlc: Double; ManUsd, ManEur, ManMlc: Boolean;
  const Estado: string; Aviso: Boolean);
begin
  asm
    if (window.CFDeudas) {
      window.CFDeudas.tasas({ USD: ValUsd, EUR: ValEur, MLC: ValMlc,
        man: { USD: ManUsd, EUR: ManEur, MLC: ManMlc } }, Estado, Aviso);
    }
  end;
end;

// ---- Puentes hacia la BD: JS los llama con un callback ----

type
  TCargarFn = procedure(Cb: TJSFunction);
  TPagarFn = procedure(DeudaId: Integer; const PagosJson: string; Cb: TJSFunction);

[async]
procedure CargarInterno(Cb: TJSFunction);
var
  R: TResultadoDeudas;
  Ok: Boolean;
  Err, Json: string;
begin
  try
    R := await(TResultadoDeudas, TDeudasService.Cargar);
    Ok := R.Ok;
    Err := R.Error;
    Json := R.Json;
  except
    Ok := False;
    Err := 'No se pudieron cargar las deudas.';
    Json := '[]';
  end;
  asm
    Cb(Ok, Err, Json);
  end;
end;

procedure CargarPuente(Cb: TJSFunction);
begin
  CargarInterno(Cb);
end;

[async]
procedure PagarInterno(DeudaId: Integer; const PagosJson: string; Cb: TJSFunction);
var
  R: TResultadoPago;
  Ok: Boolean;
  Err: string;
  Restante: Double;
begin
  try
    R := await(TResultadoPago, TDeudasService.Pagar(DeudaId, PagosJson));
    Ok := R.Ok;
    Err := R.Error;
    Restante := R.Restante;
  except
    Ok := False;
    Err := 'No se pudo registrar el pago. Revisa el historial antes de reintentar.';
    Restante := 0;
  end;
  asm
    Cb(Ok, Err, Restante);
  end;
end;

procedure PagarPuente(DeudaId: Integer; const PagosJson: string; Cb: TJSFunction);
begin
  PagarInterno(DeudaId, PagosJson, Cb);
end;

procedure PonerPuentes;
var
  FnC: TCargarFn;
  FnP: TPagarFn;
begin
  FnC := @CargarPuente;
  FnP := @PagarPuente;
  asm
    window.CFDCargar = FnC;
    window.CFDPagar = FnP;
  end;
end;

// ---- Toda la pantalla ----

procedure InstalarDeudas;
begin
  asm
    (function () {
      var todos = document.querySelectorAll('[id="dd"]');
      var root = todos.length ? todos[todos.length - 1] : null;
      if (!root) { return; }
      var g = function (id) { return root.querySelector('[id="' + id + '"]'); };

      var DEUDORES = [], filtro = 'saldo', term = '', openId = null;
      var det = null, ctx = null, fxC = 'USD', guardando = false, avisoT = 0;
      var chC = 'CUP', man = null, dejar = false;   // vuelto: moneda, reparto a mano, lo deja
      var t0 = window.CFDTasas || {};
      var R = { USD: Number(t0.USD) || 400, EUR: Number(t0.EUR) || 430, MLC: Number(t0.MLC) || 280 };
      var MAN = t0.man || { USD: false, EUR: false, MLC: false };
      var estadoT = t0.estado || 'consultando...', avisoT2 = !!t0.aviso;

      var r2 = function (x) { return Math.round(x * 100) / 100; };
      var fa = function (x) {
        return x.toLocaleString('es', { minimumFractionDigits: 0, maximumFractionDigits: 2 }).replace(/\u00a0|\u202f/g, ' ');
      };
      var esc = function (s) {
        return String(s == null ? '' : s).replace(/&/g, '&amp;').replace(/</g, '&lt;')
          .replace(/>/g, '&gt;').replace(/\x22/g, '&quot;');
      };
      var fmtF = function (iso) {
        var p = {};
        new Intl.DateTimeFormat('es', { timeZone: 'America/Havana', day: 'numeric', month: 'short',
          hour: '2-digit', minute: '2-digit', hourCycle: 'h23' })
          .formatToParts(new Date(iso)).forEach(function (x) { p[x.type] = x.value; });
        return p.day + ' ' + String(p.month).replace('.', '') + ' \u00b7 ' + p.hour + ':' + p.minute;
      };
      var n = function (id) {
        var v = parseFloat(String(g(id).value).replace(',', '.'));
        return isNaN(v) || v < 0 ? 0 : v;
      };

      // ---------- lista ----------
      var render = function () {
        var total = 0, activos = 0;
        DEUDORES.forEach(function (d) { total += d.saldo; if (d.saldo > 0.005) { activos++; } });
        g('ddTotal').textContent = fa(total) + ' CUP';
        g('ddCount').textContent = activos + (activos === 1 ? ' deudor' : ' deudores');

        var q = term.trim().toLowerCase();
        var vis = DEUDORES.filter(function (d) {
          var okF = filtro === 'saldo' ? d.saldo > 0.005 : (filtro === 'pagadas' ? d.saldo <= 0.005 : true);
          return okF && (!q || d.nombre.toLowerCase().indexOf(q) >= 0);
        });
        if (!vis.length) {
          g('ddList').innerHTML = '<div class="dd-empty">No hay deudores que coincidan con este filtro.</div>';
          return;
        }

        g('ddList').innerHTML = vis.map(function (d) {
          var pend = d.deudas.filter(function (x) { return x.saldo > 0.005; }).length;
          var open = openId === d.id;
          var ini = d.nombre.trim().charAt(0).toUpperCase();
          var inner = '';
          if (open) {
            inner = '<div class="dd-debts">' + d.deudas.map(function (x) {
              var paid = x.saldo <= 0.005;
              var pct = paid ? 100 : Math.min(99, Math.round(x.pagado / x.total * 100));
              return '<div class="dd-debt">' +
                '<div class="dd-dtop"><b>Venta #' + x.id + ' \u00b7 ' + esc(x.fecha) + '</b>' +
                '<span class="' + (paid ? 'paid' : '') + '">' + (paid ? 'Pagada' : 'Pendiente') + '</span></div>' +
                '<div class="dd-nums">' +
                '<div><small>Total</small><b>' + fa(x.total) + '</b></div>' +
                '<div><small>Pagado</small><b>' + fa(x.pagado) + '</b></div>' +
                '<div><small>Saldo</small><b>' + fa(x.saldo) + '</b></div></div>' +
                '<div class="dd-prog"><div class="dd-track"><div class="dd-fill ' + (paid ? 'done' : '') +
                '" style="width:' + pct + '%"></div></div><span class="dd-pct">' + pct + '%</span></div>' +
                '<div class="dd-acts">' +
                '<button type="button" class="dd-btn-det" data-det="' + d.id + ':' + x.id + '">Ver detalle</button>' +
                (paid ? '' :
                  '<button type="button" class="dd-btn-ab" data-pay="abonar:' + d.id + ':' + x.id + '">Abonar</button>' +
                  '<button type="button" class="dd-btn-full" data-pay="completo:' + d.id + ':' + x.id + '">Pagar completo</button>') +
                '</div></div>';
            }).join('') + '</div>';
          }
          return '<article class="dd-debtor">' +
            '<button type="button" class="dd-head" data-open="' + d.id + '" aria-expanded="' + (open ? 'true' : 'false') + '">' +
            '<div class="dd-head-l"><div class="dd-dav">' + esc(ini) + '</div><div class="dd-info"><b>' + esc(d.nombre) + '</b>' +
            '<small>' + (pend === 0 ? 'Sin deudas pendientes' : pend + (pend === 1 ? ' deuda pendiente' : ' deudas pendientes')) + '</small></div></div>' +
            '<div class="dd-bal"><b class="' + (d.saldo <= 0.005 ? 'paid' : '') + '">' + fa(d.saldo) + ' CUP</b>' +
            '<span>' + (open ? 'Ocultar \u25b2' : 'Ver deudas \u25bc') + '</span></div></button>' + inner + '</article>';
        }).join('');
      };

      var aviso = function (txt) {
        var a = g('ddAviso');
        a.textContent = txt;
        a.hidden = false;
        clearTimeout(avisoT);
        avisoT = setTimeout(function () { a.hidden = true; }, 6000);
      };

      var cargar = function (silencioso) {
        if (!silencioso) { g('ddList').innerHTML = '<div class="dd-empty">Cargando deudas...</div>'; }
        window.CFDCargar(function (ok, err, json) {
          if (!ok) { g('ddList').innerHTML = '<div class="dd-empty">' + esc(err) + '</div>'; return; }
          var arr = [];
          try { arr = JSON.parse(json) || []; } catch (e) { arr = []; }
          DEUDORES = arr.map(function (d) {
            var deudas = (d.deudas || []).map(function (x) {
              var total = Number(x.total), pagado = Number(x.pagado);
              return {
                id: x.id, fecha: fmtF(x.fecha), total: total, pagado: pagado,
                saldo: Math.max(0, r2(total - pagado)),
                items: x.items || [],
                abonos: (x.abonos || []).map(function (a) {
                  return { fecha: fmtF(a.fecha), metodo: a.metodo, monto: Number(a.monto) };
                })
              };
            });
            var saldo = 0;
            deudas.forEach(function (x) { saldo += x.saldo; });
            return { id: d.id, nombre: d.nombre, saldo: r2(saldo), deudas: deudas };
          });
          var ya = DEUDORES.some(function (d) { return d.id === openId; });
          if (!ya) {
            var primero = DEUDORES.filter(function (d) { return d.saldo > 0.005; })[0];
            openId = primero ? primero.id : null;
          }
          render();
        });
      };

      // ---------- detalle ----------
      var abrirDet = function (d, x) {
        det = { d: d, x: x };
        g('ddDetTitle').textContent = d.nombre + ' \u00b7 Venta #' + x.id;
        g('ddDetItems').innerHTML = x.items.length ? x.items.map(function (i) {
          return '<div class="dd-row"><span>' + esc(i.n) + '</span><b>' + fa(Number(i.p)) + ' CUP</b></div>';
        }).join('') : '<div class="dd-row"><span>Sin productos registrados</span><b>0 CUP</b></div>';
        g('ddDetPays').innerHTML = x.abonos.length ? x.abonos.map(function (a) {
          return '<div class="dd-row"><span>' + esc(a.fecha) + ' \u00b7 ' + esc(a.metodo) + '</span><b>' + fa(a.monto) + ' CUP</b></div>';
        }).join('') : '<div class="dd-row"><span>A\u00fan no hay abonos registrados</span><b>0 CUP</b></div>';
        g('ddDetActs').hidden = x.saldo <= 0.005;
        g('ddDetail').hidden = false;
      };

      // ---------- abonar / pagar completo (pantalla completa) ----------
      // El vuelto funciona igual que en Cobrar: si el cliente paga más que el saldo,
      // puede dejar el vuelto (ganancia) o recibirlo en CUP o en divisa + CUP.
      var f = function (x, d) {
        d = d || 0;
        return x.toLocaleString('es', { minimumFractionDigits: d, maximumFractionDigits: d }).replace(/\u00a0|\u202f/g, ' ');
      };
      var fl = function (x, d) { return Math.floor(x * Math.pow(10, d) + 1e-9) / Math.pow(10, d); };

      // Línea de tasas: de dónde sale cada una (elToque o manual de Ajustes) y de cuándo
      // son (en naranja si no son recientes). Igual que en Cobrar.
      var rotulo = function () {
        var s = function (k) { return MAN[k] ? 'manual' : 'elToque'; };
        g('ddRates').innerHTML = '1 USD = ' + R.USD + ' CUP (' + s('USD') + ') \u00b7 1 EUR = ' + R.EUR +
          ' CUP (' + s('EUR') + ') \u00b7 1 MLC = ' + R.MLC + ' CUP (' + s('MLC') + ')<br>elToque: ' + esc(estadoT) +
          ' \u00b7 <a href="#/ajustes" style="color:var(--dd-gold);text-decoration:underline">Cambiar en Ajustes</a>';
        g('ddRates').style.color = avisoT2 ? 'var(--dd-warn)' : '';
      };
      var sel = function (seg, c) {
        var bs = g(seg).querySelectorAll('button');
        for (var i = 0; i < bs.length; i++) { bs[i].classList.toggle('sel', bs[i].getAttribute('data-c') === c); }
      };
      var calc = function () {
        var cash = n('ddCash'), fx = n('ddFx'), trf = n('ddTrf'), mlc = n('ddMlc');
        var fxCup = r2(fx * R[fxC]), mlcCup = r2(mlc * R.MLC);
        var paid = r2(cash + fxCup + trf + mlcCup);
        return { cash: cash, fx: fx, trf: trf, mlc: mlc, fxCup: fxCup, mlcCup: mlcCup,
                 paid: paid, diff: r2(paid - ctx.x.saldo) };
      };

      // ----- vuelto (copiado de Cobrar) -----
      var totalText = function (diff) {
        if (chC === 'CUP' || !calc().fx) { return fa(diff) + ' CUP'; }
        return f(fl(diff / R[chC], 2), 2) + ' ' + chC;
      };
      // Automático: divisa en unidades enteras y el resto en CUP exacto.
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
        if (which !== 'fx') { g('ddChFx').value = sp.fx ? String(sp.fx) : ''; }
        if (which !== 'cup') { g('ddChCup').value = sp.cup ? String(sp.cup) : ''; }
        var over = false, r = R[chC];
        if (man && man.field === 'fx') { over = man.v * r > d + 0.01; }
        else if (man) { over = man.v > d - sp.fx * r + 0.01; }
        g('ddChgAmt').textContent = over
          ? 'No puedes devolver m\u00e1s del vuelto total (' + totalText(d) + ')'
          : 'Vuelto total: ' + totalText(d) + ' = ' + fa(d) + ' CUP';
      };

      var updPay = function () {
        if (!ctx) { return; }
        man = null;
        var c = calc(), s = g('ddPayStat'), ok = g('ddPayOk');
        g('ddFxEq').textContent = c.fx ? fa(c.fx) + ' ' + fxC + ' \u00d7 ' + R[fxC] + ' = ' + fa(c.fxCup) + ' CUP'
                                        : '1 ' + fxC + ' = ' + R[fxC] + ' CUP';
        g('ddMlcEq').textContent = c.mlc ? fa(c.mlc) + ' MLC \u00d7 ' + R.MLC + ' = ' + fa(c.mlcCup) + ' CUP'
                                          : 'Cuenta como transferencia';
        g('ddSumCash').textContent = fa(r2(c.cash + c.fxCup)) + ' CUP';
        g('ddSumTrf').textContent = fa(r2(c.trf + c.mlcCup)) + ' CUP';

        var hayVuelto = c.diff > 0.005;
        if (!hayVuelto) { dejar = false; g('ddDejar').checked = false; }
        g('ddKeep').hidden = !hayVuelto;
        g('ddDejarAmt').textContent = '(' + fa(c.diff) + ' CUP)';
        var showChg = hayVuelto && c.fx > 0 && !dejar;
        if (!(hayVuelto && c.fx > 0) && chC !== 'CUP') { chC = 'CUP'; sel('ddChgSeg', 'CUP'); }

        var invalido = false, color;
        if (c.paid <= 0) {
          color = 'var(--dd-mut)'; s.textContent = 'Escribe cu\u00e1nto paga el cliente'; invalido = true;
        } else if (c.diff < -0.005) {
          color = 'var(--dd-gold)'; s.textContent = 'Abono de ' + fa(c.paid) + ' CUP \u00b7 quedan ' + fa(-c.diff) + ' CUP';
        } else if (c.diff <= 0.005) {
          color = 'var(--dd-ok)'; s.textContent = 'Pago completo: la deuda queda saldada';
        } else if (dejar) {
          color = 'var(--dd-ok)'; s.textContent = 'Vuelto dejado: ' + fa(c.diff) + ' CUP (ganancia)';
        } else {
          color = 'var(--dd-gold)'; s.textContent = 'Vuelto: ' + totalText(c.diff);
        }
        s.style.color = color;
        var fill = g('ddPayFill');
        fill.style.width = Math.min(100, ctx.x.saldo > 0 ? c.paid / ctx.x.saldo * 100 : 0) + '%';
        fill.style.background = color;

        g('ddChg').hidden = !showChg;
        if (showChg) {
          g('ddBrk').hidden = chC === 'CUP';
          g('ddChFxL').textContent = 'Entregas en ' + chC;
          fillSplit();
        }
        g('ddPayOkTxt').textContent = c.diff >= -0.005 ? 'Confirmar pago completo' : 'Confirmar abono';
        ok.disabled = invalido || guardando;
        g('ddPayMsg').textContent = '';
      };
      var abrirPago = function (d, x, modo) {
        ctx = { d: d, x: x };
        g('ddPayTitle').textContent = modo === 'completo' ? 'Pagar completo' : 'Abonar';
        g('ddPayWho').textContent = d.nombre + ' \u00b7 Venta #' + x.id;
        g('ddPaySaldo').textContent = fa(x.saldo) + ' CUP';
        var ids = ['ddCash', 'ddFx', 'ddTrf', 'ddMlc', 'ddChFx', 'ddChCup'];
        for (var i = 0; i < ids.length; i++) { g(ids[i]).value = ''; }
        if (modo === 'completo') { g('ddCash').value = String(x.saldo); }
        fxC = 'USD'; sel('ddFxSeg', 'USD');
        chC = 'CUP'; sel('ddChgSeg', 'CUP');
        dejar = false; g('ddDejar').checked = false; man = null;
        rotulo();
        g('ddPayForm').hidden = false;
        g('ddPayDone').hidden = true;
        g('ddMain').hidden = true;
        g('ddPayView').hidden = false;
        window.scrollTo(0, 0);
        updPay();
      };
      var cerrarPago = function () {
        g('ddPayView').hidden = true;
        g('ddMain').hidden = false;
        ctx = null;
      };
      var setAll = function (id) {
        var ids = ['ddCash', 'ddFx', 'ddTrf', 'ddMlc'];
        for (var i = 0; i < ids.length; i++) { g(ids[i]).value = ''; }
        g(id).value = String(ctx.x.saldo);
        updPay();
      };
      // vueltoTxt se calcula antes de guardar, para que no cambie si llega otra tasa
      var mostrarHecho = function (c, k, sal, vueltoTxt) {
        var L = [];
        if (c.cash) { L.push('Efectivo (CUP): <b>' + fa(c.cash) + ' CUP</b>'); }
        if (c.fx) { L.push('Divisa en efectivo: <b>' + fa(c.fx) + ' ' + fxC + '</b> (' + fa(c.fxCup) + ' CUP)'); }
        if (c.trf) { L.push('Transferencia (CUP): <b>' + fa(c.trf) + ' CUP</b>'); }
        if (c.mlc) { L.push('MLC (transferencia): <b>' + fa(c.mlc) + ' MLC</b> (' + fa(c.mlcCup) + ' CUP)'); }
        if (c.diff > 0.005) {
          L.push('Recibido: <b>' + fa(c.paid) + ' CUP</b>');
          L.push('Abonado a la deuda: <b>' + fa(k.x.saldo) + ' CUP</b>');
          if (dejar) { L.push('Vuelto dejado (ganancia): <b>' + fa(c.diff) + ' CUP</b>'); }
          else { L.push('Vuelto entregado: <b>' + esc(vueltoTxt) + '</b>'); }
        } else {
          L.push('Total abonado: <b>' + fa(c.paid) + ' CUP</b>');
        }
        L.push(sal <= 0.005 ? 'La deuda queda saldada' : 'Quedan <b>' + fa(sal) + ' CUP</b>');
        g('ddDoneTit').textContent = sal <= 0.005 ? 'Deuda saldada' : 'Abono registrado';
        g('ddDoneWho').textContent = k.d.nombre + ' \u00b7 Venta #' + k.x.id;
        g('ddDoneTxt').innerHTML = L.join('<br>');
        g('ddPayForm').hidden = true;
        g('ddPayDone').hidden = false;
        window.scrollTo(0, 0);
      };
      // Pagos tal como entraron, restando el vuelto entregado
      // (orden: efectivo, divisa, transferencia, MLC), igual que en Cobrar.
      // Si el cliente deja el vuelto, se manda todo lo que pagó.
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
      var confirmar = function () {
        if (guardando || !ctx) { return; }
        var c = calc();
        if (c.paid <= 0) { updPay(); return; }
        var k = ctx;                                        // por si sales mientras guarda
        var vueltoTxt = c.diff > 0.005 && !dejar ? changeText(c.diff) : '';
        guardando = true;
        g('ddPayOk').disabled = true;
        g('ddPayMsg').textContent = 'Guardando...';
        window.CFDPagar(k.x.id, JSON.stringify(armarPagos(c)), function (ok, err, restante) {
          guardando = false;
          if (!ok) { g('ddPayOk').disabled = false; g('ddPayMsg').textContent = err || 'No se pudo registrar el pago.'; return; }
          var sal = Number(restante) || 0;
          if (ctx === k) { mostrarHecho(c, k, sal, vueltoTxt); }
          g('ddPayMsg').textContent = '';
          cargar(true);
        });
      };

      // ---------- eventos ----------
      root.addEventListener('click', function (e) {
        var t = e.target;
        if (!t || !t.closest) { return; }
        if (t.id === 'ddDetail') { g('ddDetail').hidden = true; return; }

        var o = t.closest('[data-open]');
        if (o) { var oid = Number(o.getAttribute('data-open')); openId = openId === oid ? null : oid; render(); return; }

        var dt = t.closest('[data-det]');
        if (dt) {
          var a = dt.getAttribute('data-det').split(':').map(Number);
          var dd = DEUDORES.filter(function (x) { return x.id === a[0]; })[0];
          var xx = dd && dd.deudas.filter(function (x) { return x.id === a[1]; })[0];
          if (xx) { abrirDet(dd, xx); }
          return;
        }

        var pb = t.closest('[data-pay]');
        if (pb) {
          var p = pb.getAttribute('data-pay').split(':');
          var d2 = DEUDORES.filter(function (x) { return x.id === Number(p[1]); })[0];
          var x2 = d2 && d2.deudas.filter(function (x) { return x.id === Number(p[2]); })[0];
          if (x2) { abrirPago(d2, x2, p[0]); }
          return;
        }

        var b = t.closest('button');
        if (!b) { return; }
        var id = b.id, pid = b.parentNode ? b.parentNode.id : '';
        if (id === 'ddDetClose') { g('ddDetail').hidden = true; }
        else if (id === 'ddDetAb' || id === 'ddDetFull') {
          var cur = det; g('ddDetail').hidden = true;
          if (cur) { abrirPago(cur.d, cur.x, id === 'ddDetFull' ? 'completo' : 'abonar'); }
        }
        else if (id === 'ddPayClose' || id === 'ddDoneBack') { cerrarPago(); }
        else if (id === 'ddBack') {
          if (window.history.length > 1) { window.history.back(); }
          else { window.location.hash = '/vender'; }
        }
        else if (id === 'ddPayOk') { confirmar(); }
        else if (id === 'ddAllCash') { if (ctx) { setAll('ddCash'); } }
        else if (id === 'ddAllTrf') { if (ctx) { setAll('ddTrf'); } }
        else if (pid === 'ddFxSeg') { fxC = b.getAttribute('data-c'); sel('ddFxSeg', fxC); updPay(); }
        else if (pid === 'ddChgSeg') { chC = b.getAttribute('data-c'); sel('ddChgSeg', chC); updPay(); }
        else if (pid === 'ddChips') {
          filtro = b.getAttribute('data-f');
          var bs = g('ddChips').querySelectorAll('button');
          for (var i = 0; i < bs.length; i++) { bs[i].classList.toggle('on', bs[i] === b); }
          render();
        }
      });

      root.addEventListener('input', function (e) {
        var id = e.target ? e.target.id : '';
        if (id === 'ddBusca') { term = e.target.value; render(); }
        else if (id === 'ddCash' || id === 'ddFx' || id === 'ddTrf' || id === 'ddMlc') { updPay(); }
        else if (id === 'ddChFx') { man = { field: 'fx', v: n('ddChFx') }; fillSplit('fx'); }
        else if (id === 'ddChCup') { man = { field: 'cup', v: n('ddChCup'), fx: n('ddChFx') }; fillSplit('cup'); }
      });

      root.addEventListener('change', function (e) {
        if (e.target && e.target.id === 'ddDejar') { dejar = !!e.target.checked; updPay(); }
      });

      // Para que Pascal cambie las tasas cuando elToque responde
      window.CFDeudas = {
        tasas: function (t, estado, aviso) {
          R = { USD: Number(t.USD), EUR: Number(t.EUR), MLC: Number(t.MLC) };
          MAN = t.man || MAN;
          estadoT = estado; avisoT2 = !!aviso;
          rotulo();
          if (ctx && g('ddPayDone').hidden) { updPay(); }   // no recalcula si el pago ya se confirm\u00f3
        }
      };

      var red = function () {
        if (!root.isConnected) {
          window.removeEventListener('online', red);
          window.removeEventListener('offline', red);
          return;
        }
        g('ddNet').textContent = navigator.onLine ? 'En l\u00ednea' : 'Sin conexi\u00f3n';
        g('ddNet').classList.toggle('dd-off', !navigator.onLine);
      };
      window.addEventListener('online', red);
      window.addEventListener('offline', red);
      red();

      cargar(false);
    })();
  end;
end;

procedure TForm11.WebFormCreate(Sender: TObject);
var
  T: TTasasCup;
  Estado: string;
begin
  TNavegacion.Registrar(Self);
  TShell.Actual := Self;
  TShell.Activar('mas');         // marca "Más" en el menú inferior

  // La pantalla abre ya con la última tasa guardada; elToque se consulta detrás
  T := TTasas.Guardada;
  if T.Origen = 'ejemplo' then
    Estado := 'sin tasa guardada, consultando...'
  else
    Estado := 'consultando...';
  PonerTasasD(T.EfUsd, T.EfEur, T.EfMlc, T.ManUsd, T.ManEur, T.ManMlc, Estado, T.Origen = 'ejemplo');
  PonerPuentes;
  InstalarDeudas;
  ActualizarTasas;
end;

procedure TForm11.ActualizarTasas;
var
  T: TTasasCup;
begin
  T := await(TTasasCup, TTasas.Consultar);
  if TShell.Actual <> Self then Exit;          // ya saliste de esta pantalla
  AplicarTasasD(T.EfUsd, T.EfEur, T.EfMlc, T.ManUsd, T.ManEur, T.ManMlc, EstadoDe(T), T.Origen <> 'toque');
end;

end.
