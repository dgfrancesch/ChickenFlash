unit uShell;

interface

uses
  System.SysUtils, System.Classes, JS, Web, WEBLib.Forms;

type
  TShellNavegarEvent = reference to procedure(const Destino: string);

  TShell = class
  public
  class var Actual: TWebForm;
  class var Destino: string;
    class var AlNavegar: TShellNavegarEvent;
    class procedure Iniciar;                       // crea todo una sola vez
    class procedure Activar(const ADestino: string); // resalta vender/inventario/caja
    class procedure Mostrar;
    class procedure Ocultar;
    class procedure AbrirPanel;
    class procedure CerrarPanel;
        class procedure PonerInicial;
  end;

implementation

uses
  uSession, uAuthService, uPie,uNavegacion;

[async]
procedure Salir;
begin
  await(Boolean, TAuthService.Logout);
  // quita el #/ruta sin añadir historial, para que el login quede en la URL limpia
  window.history.replaceState(nil, '', window.location.pathname + window.location.search);
  window.location.reload(False);
end;

function BuscarAncestro(El: TJSElement; const Selector: string): TJSElement;
begin
  asm
    Result = El.closest(Selector);
  end;
end;

function AlClic(Event: TJSEvent): Boolean;
var
  Objetivo, El: TJSElement;
  Destino, Accion: string;
begin
  Result := True;
  Objetivo := TJSElement(Event.target);

  El := BuscarAncestro(Objetivo, '[data-accion]');
  if El <> nil then
  begin
    Accion := string(El.getAttribute('data-accion'));
    if Accion = 'cerrar' then TShell.CerrarPanel
    else if Accion = 'salir' then Salir;
    Exit;
  end;

  El := BuscarAncestro(Objetivo, '[data-destino]');
  if El = nil then Exit;
  Destino := string(El.getAttribute('data-destino'));

  if Destino = 'mas' then
  begin
    TShell.AbrirPanel;
    Exit;
  end;

  TShell.CerrarPanel;
  if (Destino = 'vender') or (Destino = 'inventario') or (Destino = 'caja') then
    TShell.Activar(Destino);
  if Assigned(TShell.AlNavegar) then
    TShell.AlNavegar(Destino);
end;

class procedure TShell.Iniciar;
var
  Nombre: string;
begin
  if document.getElementById('shell') = nil then
  begin
    asm
      const html = `
<div id="shell">
  <svg width="0" height="0" style="position:absolute" aria-hidden="true">
    <symbol id="sh-home" viewBox="0 0 24 24"><path d="M3 11l9-8 9 8M5 10v10h14V10"/></symbol>
    <symbol id="sh-box" viewBox="0 0 24 24"><path d="M21 8l-9-5-9 5v8l9 5 9-5zM3 8l9 5 9-5M12 13v8"/></symbol>
    <symbol id="sh-cash" viewBox="0 0 24 24"><rect x="2" y="6" width="20" height="12" rx="2"/><circle cx="12" cy="12" r="2.6"/><path d="M6 12h.01M18 12h.01"/></symbol>
    <symbol id="sh-dots" viewBox="0 0 24 24"><circle cx="5" cy="12" r="1.3"/><circle cx="12" cy="12" r="1.3"/><circle cx="19" cy="12" r="1.3"/></symbol>
    <symbol id="sh-close" viewBox="0 0 24 24"><path d="M18 6L6 18M6 6l12 12"/></symbol>
    <symbol id="sh-historial" viewBox="0 0 24 24"><circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/></symbol>
    <symbol id="sh-tasa" viewBox="0 0 24 24"><path d="M7 4L3 8l4 4M3 8h14M17 20l4-4-4-4M21 16H7"/></symbol>
    <symbol id="sh-gasto" viewBox="0 0 24 24"><rect x="3" y="6" width="18" height="14" rx="2"/><path d="M3 10h18M16 15h2"/></symbol>
    <symbol id="sh-reporte" viewBox="0 0 24 24"><path d="M4 20V11M10 20V4M16 20v-8M21 20H3"/></symbol>
    <symbol id="sh-ajustes" viewBox="0 0 24 24"><path d="M4 7h10M18 7h2M4 17h2M10 17h10"/><circle cx="16" cy="7" r="2"/><circle cx="8" cy="17" r="2"/></symbol>
    <symbol id="sh-salir" viewBox="0 0 24 24"><path d="M15 3h4a2 2 0 012 2v14a2 2 0 01-2 2h-4M10 17l5-5-5-5M15 12H3"/></symbol>
    <symbol id="sh-chevron" viewBox="0 0 24 24"><path d="M9 6l6 6-6 6"/></symbol>
  </svg>

  <nav class="sh-nav" aria-label="Navegación">
    <button class="sh-nav-item on" type="button" data-destino="vender"><svg class="sh-i"><use href="#sh-home"/></svg><span>Vender</span></button>
    <button class="sh-nav-item" type="button" data-destino="inventario"><svg class="sh-i"><use href="#sh-box"/></svg><span>Inventario</span></button>
    <button class="sh-nav-item" type="button" data-destino="caja"><svg class="sh-i"><use href="#sh-cash"/></svg><span>Caja</span></button>
    <button class="sh-nav-item" type="button" data-destino="mas"><svg class="sh-i"><use href="#sh-dots"/></svg><span>Más</span></button>
  </nav>

  <footer class="sh-pie" id="pieShell">Chicken Flash • Sistema de Punto de Venta e Inventario</footer>

  <div class="sh-panel" id="shPanel">
    <button class="sh-fondo" type="button" data-accion="cerrar" aria-label="Cerrar menú" tabindex="-1"></button>
    <aside class="sh-lado" aria-label="Menú">
      <header class="sh-lado-cab">
        <div class="sh-av" id="shInicial">J</div>
        <div class="sh-quien"><b id="shNombre">Usuario</b><small>Administrador</small></div>
        <button class="sh-x" type="button" data-accion="cerrar" aria-label="Cerrar"><svg class="sh-i"><use href="#sh-close"/></svg></button>
      </header>
      <div class="sh-lado-menu">
        <button class="sh-item" type="button" data-destino="historial"><svg class="sh-i"><use href="#sh-historial"/></svg><span>Historial de ventas</span><svg class="sh-i sh-chev"><use href="#sh-chevron"/></svg></button>
        <button class="sh-item" type="button" data-destino="tasas"><svg class="sh-i"><use href="#sh-tasa"/></svg><span>Tasas de cambio</span><svg class="sh-i sh-chev"><use href="#sh-chevron"/></svg></button>
        <button class="sh-item" type="button" data-destino="compras"><svg class="sh-i"><use href="#sh-gasto"/></svg><span>Compras y gastos</span><svg class="sh-i sh-chev"><use href="#sh-chevron"/></svg></button>
        <button class="sh-item" type="button" data-destino="reportes"><svg class="sh-i"><use href="#sh-reporte"/></svg><span>Reportes</span><svg class="sh-i sh-chev"><use href="#sh-chevron"/></svg></button>
        <button class="sh-item" type="button" data-destino="ajustes"><svg class="sh-i"><use href="#sh-ajustes"/></svg><span>Ajustes</span><svg class="sh-i sh-chev"><use href="#sh-chevron"/></svg></button>
      </div>
      <button class="sh-item sh-item--salir" type="button" data-accion="salir"><svg class="sh-i"><use href="#sh-salir"/></svg><span>Cerrar sesión</span></button>
    </aside>
  </div>
</div>`;
      document.body.insertAdjacentHTML('beforeend', html);
    end;

    document.getElementById('shell').addEventListener('click', @AlClic);
    PonerPie('pieShell');
  end;

  Nombre := TSession.UserName;
  document.getElementById('shNombre').innerHTML := Nombre;
  document.getElementById('shInicial').innerHTML := UpperCase(Copy(Nombre, 1, 1));
  Mostrar;
end;

class procedure TShell.Mostrar;
begin
  document.getElementById('shell').removeAttribute('hidden');
  document.body.classList.add('sh-activo');
end;

class procedure TShell.Ocultar;
begin
  document.getElementById('shell').setAttribute('hidden', '');
  document.body.classList.remove('sh-activo');
  CerrarPanel;
end;

class procedure TShell.AbrirPanel;
begin
  document.getElementById('shPanel').classList.add('abierto');
end;

class procedure TShell.CerrarPanel;
begin
  document.getElementById('shPanel').classList.remove('abierto');
end;

class procedure TShell.Activar(const ADestino: string);
var
  Items: TJSNodeList;
  i: Integer;
  El: TJSElement;
begin
  Destino := ADestino;
  Iniciar;
  Items := document.querySelectorAll('.sh-nav-item');
  for i := 0 to Items.length - 1 do
  begin
    El := TJSElement(Items.item(i));
    if string(El.getAttribute('data-destino')) = ADestino then
      El.classList.add('on')
    else
      El.classList.remove('on');
  end;
end;

class procedure TShell.PonerInicial;
var
  Inicial: string;
begin
  Inicial := UpperCase(Copy(TSession.UserName, 1, 1));
  asm
    const el = document.getElementById('lblInicial');
    if (el) el.innerHTML = Inicial;
  end;
end;

end.
