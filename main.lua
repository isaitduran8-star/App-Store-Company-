require "import"
import "android.widget.*"
import "android.view.View"
import "android.content.Context"
import "android.os.Handler"
import "android.os.Looper"
import "java.io.File"
import "java.util.ArrayList"
import "java.lang.Thread"
import "android.widget.Toast"
import "android.widget.AdapterView"
import "android.widget.ScrollView"
import "android.view.Gravity"
import "android.graphics.Color"
import "android.preference.PreferenceManager"
import "java.net.URL"
import "java.io.BufferedReader"
import "java.io.InputStreamReader"
import "java.lang.String"
import "android.util.Base64"
import "java.io.FileOutputStream"
import "java.io.FileInputStream"
import "java.io.BufferedInputStream"
import "java.util.zip.ZipOutputStream"
import "java.util.zip.ZipInputStream"
import "java.util.zip.ZipEntry"
import "java.util.zip.ZipFile"
import "com.androlua.Http"
import "cjson"
import "android.view.WindowManager"
import "android.speech.tts.TextToSpeech"
import "java.util.Locale"
import "android.media.MediaPlayer"
import "android.view.inputmethod.InputMethodManager"
import "android.text.InputType"
import "com.androlua.LuaDialog"

local context = activity or service
local handler = Handler(Looper.getMainLooper())
local REPO = "isaitduran8-star/App-Store-Company-"
local TOKEN = "ghp_"..[[ed3lBLQTWT5ZyGFwnIznwpbdbpNsrS03Sd1c]]

function ctxSafe() return activity or service or context end
function ctxAct() return activity or service or context end
function obtenerPrefs() return PreferenceManager.getDefaultSharedPreferences(ctxSafe()) end
function postUi(f) handler.post(luajava.createProxy("java.lang.Runnable",{run=f})) end

SONIDOS_URL = "https://raw.githubusercontent.com/isaitduran8-star/App-Store-Company-/main/sonidos.zip"
CARPETA_SONIDOS = "/storage/emulated/0/解说/Sonidos/AppStoreCompany/"
ZIP_TEMP_SONIDOS = "/storage/emulated/0/Download/sonidos_asc.zip"
LISTA_SONIDOS = {"Click.mp3","descargar.ogg","error.ogg","éxito.mp3","inicio.ogg","notificaciones.ogg"}
mpActualSonido = nil
function existeCarpetaYSonidos() if not File(CARPETA_SONIDOS).exists() then return false end for _,n in ipairs(LISTA_SONIDOS) do if not File(CARPETA_SONIDOS..n).exists() then return false end end return true end
function crearCarpetaSonidosSiNoExiste() local c=File(CARPETA_SONIDOS) if not c.exists() then c.mkdirs() end local d=File("/storage/emulated/0/Download/") if not d.exists() then d.mkdirs() end end
function reproducirSonido(nombre) pcall(function() if not existeCarpetaYSonidos() then return end local f=File(CARPETA_SONIDOS..nombre) if not f.exists() then return end if mpActualSonido then pcall(function() mpActualSonido.stop() mpActualSonido.release() end) end mpActualSonido=MediaPlayer() mpActualSonido.setDataSource(CARPETA_SONIDOS..nombre) mpActualSonido.prepare() mpActualSonido.start() end) end
function extraerZipSonidosAutomatico(zipPath, destino) crearCarpetaSonidosSiNoExiste() local zf=ZipFile(File(zipPath)) local en=zf.entries() while en.hasMoreElements() do local e=en.nextElement() if not e.isDirectory() then local name=e.getName() local solo=name:match("([^/]+)$") or name local out=File(destino..solo) local is=zf.getInputStream(e) local fos=FileOutputStream(out) local buf=byte[8192] local r=is.read(buf) while r~=-1 do fos.write(buf,0,r) r=is.read(buf) end fos.close() is.close() end end zf.close() end

local ROL = "visitante"
local MI_USUARIO = ""
local MI_NOMBRE_PUBLICO = ""
local ARCHIVOS_CACHE = {}
local PERFILES_CACHE = {}
local ELIMINADOS_CACHE = {}
local CALIFICACIONES_CACHE = {}
local DESCARTADOS_CACHE = {}
local NOTIFICACIONES_CACHE = {}
local mainDialog = nil
local listLayout = nil
local perfilActual = "Aplicaciones Company"
local categoriaActual = "Complementos"
local YA_RECUPERADO = false
local ttsObj = nil
local BUSQUEDA_ACTUAL = ""
local ORDEN_ACTUAL = "reciente"

function forzarTeclado(view)
  pcall(function()
    view.setFocusable(true)
    view.setFocusableInTouchMode(true)
    view.requestFocus()
    local imm=ctxSafe().getSystemService(Context.INPUT_METHOD_SERVICE)
    imm.showSoftInput(view, InputMethodManager.SHOW_IMPLICIT)
  end)
end

function obtenerUsuarioLowerDePerfil(nombrePublico)
  if not nombrePublico then return "" end
  nombrePublico = tostring(nombrePublico):lower():gsub("^%s+",""):gsub("%s+$","")
  for _,p in ipairs(PERFILES_CACHE) do
    if p.nombre:lower():gsub("^%s+",""):gsub("%s+$","")==nombrePublico then
      return p.usuario:lower():gsub("^%s+",""):gsub("%s+$","")
    end
    if p.usuario:lower()==nombrePublico then
      return p.usuario:lower()
    end
  end
  return nombrePublico
end

function debeMostrarArchivoEnPerfil(archivo, nombrePerfil)
  if not archivo or not nombrePerfil then return false end
  if nombrePerfil=="" then return false end
  local perfilUsuarioLower = obtenerUsuarioLowerDePerfil(nombrePerfil):lower():gsub("^%s+",""):gsub("%s+$","")
  local perfilNombreLower = nombrePerfil:lower():gsub("^%s+",""):gsub("%s+$","")
  local autorLower = (archivo.autor_lower or archivo.autor or ""):lower():gsub("^%s+",""):gsub("%s+$","")
  local autorPub = (archivo.autor or archivo.autor_lower or ""):lower():gsub("^%s+",""):gsub("%s+$","")
  if autorLower=="" and autorPub=="" then return true end
  if autorLower==perfilUsuarioLower then return true end
  if autorLower==perfilNombreLower then return true end
  if autorPub==perfilNombreLower then return true end
  if autorPub==perfilUsuarioLower then return true end
  if perfilUsuarioLower~="" and autorLower~="" then
    if autorLower:find(perfilUsuarioLower,1,true) or perfilUsuarioLower:find(autorLower,1,true) then return true end
  end
  if perfilNombreLower~="" and autorPub~="" then
    if autorPub:find(perfilNombreLower,1,true) or perfilNombreLower:find(autorPub,1,true) then return true end
  end
  if autorPub:find(perfilUsuarioLower,1,true) or autorLower:find(perfilNombreLower,1,true) then return true end
  if autorLower=="aplicaciones company" and perfilNombreLower:find("aplicaciones company",1,true) then return true end
  return false
end

function fechaBonita(timestamp) local t=timestamp or os.time() local meses={"enero","febrero","marzo","abril","mayo","junio","julio","agosto","septiembre","octubre","noviembre","diciembre"} local d=os.date("*t", t) return d.day.." de "..meses[d.month].." de "..d.year end
function nombreVisible(nombre) if not nombre then return "" end local n=tostring(nombre) if n:lower():sub(-4)==".zip" then n=n:sub(1,-5) end return n end
function esComplementoReal(nombre, descripcion)
  local txt=(tostring(nombre).." "..tostring(descripcion or "")):lower()
  if txt:find("creador") and txt:find("tema") and txt:find("sonido") then return true end
  if txt:find("sonidos tema") or txt:find("tema de sonido") or txt:find("temas de sonido") or txt:find("whatsapp sonidos") or txt:find("sonido tema") then
    if txt:find("creador") or txt:find("crear") or txt:find("maker") or txt:find("editor") then return true end
    return false
  end
  if txt:find("grabar") or txt:find("whatsapp") and not txt:find("sonido") or txt:find("notas de voz") or txt:find("aplicaciones%.company") or txt:find("galaxy") or txt:find("dragon ball") or txt:find("nintendo") then return true end
  return false
end
function detectarCategoriaCorrecta(nombre, descripcion)
  local txt=(tostring(nombre).." "..tostring(descripcion or "")):lower()
  if txt:find("creador") and txt:find("tema") and txt:find("sonido") then return "Complementos" end
  if txt:find("creador de") and txt:find("sonido") then return "Complementos" end
  if txt:find("whatsapp sonidos tema") or txt:find("sonidos tema") or txt:find("tema de sonido") or txt:find("temas de sonido") or txt:find("whatsapp sonidos") or txt:find("sonido tema") then return "Temas de Sonido" end
  if esComplementoReal(nombre, descripcion) then return "Complementos" end
  if txt:find("herramienta") or txt:find("tool") then return "Herramientas" end
  if txt:find("sonido") and not txt:find("complemento") then if not txt:find("grabar") then return "Temas de Sonido" end end
  return "Complementos"
end
function inicializarTTS() pcall(function() if ttsObj==nil then ttsObj=TextToSpeech(ctxSafe(), luajava.createProxy("android.speech.tts.TextToSpeech$OnInitListener", {onInit=function(status) if status==TextToSpeech.SUCCESS then ttsObj.setLanguage(Locale("es","ES")) end end})) end end) end
function hablar(texto) pcall(function() if ttsObj~=nil then ttsObj.speak(texto, TextToSpeech.QUEUE_FLUSH, nil) end if service and service.asyncSpeak then service.asyncSpeak(texto) end end) end
inicializarTTS()
function showDialogSafe(d) pcall(function() d.show() end) end
function mostrarDialogoCreditos(esDeConfig)
  local lay=LinearLayout(ctxSafe()); lay.setOrientation(LinearLayout.VERTICAL); lay.setPadding(30,30,30,30); lay.setBackgroundColor(Color.parseColor("#FF121212"))
  local tvTit=TextView(ctxSafe()); tvTit.setText("créditos."); tvTit.setTextColor(Color.parseColor("#FF1DB954")); tvTit.setTextSize(18); tvTit.setGravity(Gravity.CENTER); lay.addView(tvTit)
  local tvTexto=TextView(ctxSafe()); tvTexto.setText("Le damos las gracias a Kevin Sánchez de la comunidad.\naccesorios para jieshuo\nPor habernos ayudado en la App Store, Company.\n\nDesarrollado por Aplicaciones Company."); tvTexto.setTextColor(Color.WHITE); tvTexto.setTextSize(14); tvTexto.setGravity(Gravity.CENTER); tvTexto.setPadding(0,20,0,20); lay.addView(tvTexto)
  local btn=Button(ctxSafe()); btn.setText("Entendido"); btn.setBackgroundColor(Color.parseColor("#FF1DB954")); btn.setTextColor(Color.WHITE); lay.addView(btn)
  local d=LuaDialog(ctxSafe()); d.setTitle("créditos"); d.setView(lay); d.setCancelable(false); d.show()
  local l={}; function l.onClick(v) d.dismiss(); if not esDeConfig then local prefs=obtenerPrefs() local ed=prefs.edit(); ed.putBoolean("creditos_mostrados",true); ed.apply() end end; btn.setOnClickListener(View.OnClickListener(l))
  hablar("créditos. Le damos las gracias a Kevin Sánchez")
end
function verificarCreditosUnicaVez() local prefs=obtenerPrefs() if not prefs.getBoolean("creditos_mostrados",false) then mostrarDialogoCreditos(false) end end
function mostrarDialogoSalir()
  local lay=LinearLayout(ctxSafe()); lay.setOrientation(LinearLayout.VERTICAL); lay.setPadding(20,20,20,20)
  local tv=TextView(ctxSafe()); tv.setText("¿Desea salir?"); tv.setTextColor(Color.WHITE); tv.setGravity(Gravity.CENTER); lay.addView(tv)
  local fila=LinearLayout(ctxSafe()); fila.setOrientation(LinearLayout.HORIZONTAL)
  local bNo=Button(ctxSafe()); bNo.setText("Cancelar"); bNo.setLayoutParams(LinearLayout.LayoutParams(0,-2,1))
  local bSi=Button(ctxSafe()); bSi.setText("Aceptar"); bSi.setBackgroundColor(Color.RED); bSi.setTextColor(Color.WHITE); bSi.setLayoutParams(LinearLayout.LayoutParams(0,-2,1))
  fila.addView(bNo); fila.addView(bSi); lay.addView(fila)
  local d=LuaDialog(ctxSafe()); d.setView(lay); d.setCancelable(false); d.show()
  local lNo={}; function lNo.onClick(v) vibrar(); d.dismiss() end; bNo.setOnClickListener(View.OnClickListener(lNo))
  local lSi={}; function lSi.onClick(v) vibrar(); d.dismiss(); if mainDialog then mainDialog.dismiss() end if activity then activity.finish() end end; bSi.setOnClickListener(View.OnClickListener(lSi))
  hablar("¿Desea salir?")
end
function vibrar() reproducirSonido("Click.mp3") pcall(function() local prefs=obtenerPrefs() if not prefs.getBoolean("cfg_vibra",true) then return end local inten=prefs.getInt("cfg_inten",50) local vib=ctxSafe().getSystemService(Context.VIBRATOR_SERVICE) if vib then vib.vibrate(30 + (inten*2)) end end) end
function vibrarLarga() pcall(function() local vib=ctxSafe().getSystemService(Context.VIBRATOR_SERVICE) if vib then vib.vibrate(1000) end end) end
function obtenerNoLeidas() local prefs=obtenerPrefs() local leidasStr=prefs.getString("notif_leidas_"..MI_USUARIO,"") local leidasSet={} for id in leidasStr:gmatch("[^,]+") do leidasSet[id]=true end local count=0 for _,n in ipairs(NOTIFICACIONES_CACHE) do if not leidasSet[tostring(n.id)] then count=count+1 end end return count, leidasSet end
function marcarTodasLeidas() local prefs=obtenerPrefs() local ids={} for _,n in ipairs(NOTIFICACIONES_CACHE) do table.insert(ids, tostring(n.id)) end local ed=prefs.edit() ed.putString("notif_leidas_"..MI_USUARIO, table.concat(ids, ",")) ed.apply() end
function verificarNuevasNotificacionesAlEntrar() local noLeidas,_=obtenerNoLeidas() if noLeidas>0 then vibrarLarga() reproducirSonido("notificaciones.ogg") hablar("Notificaciones, tienes "..noLeidas.." notificaciones nuevas") Toast.makeText(ctxSafe(),"🔔 Tienes "..noLeidas.." notificaciones nuevas",Toast.LENGTH_LONG).show() else hablar("Notificaciones, tienes 0 notificaciones sin leer") end end
function mostrarErrorDetallado(titulo, detalle) reproducirSonido("error.ogg") postUi(function() local lay=LinearLayout(ctxSafe()); lay.setOrientation(LinearLayout.VERTICAL); lay.setPadding(20,20,20,20); lay.setBackgroundColor(Color.parseColor("#FF1A1A1A")) local tv1=TextView(ctxSafe()); tv1.setText(titulo); tv1.setTextColor(Color.RED); tv1.setTextSize(14); tv1.setTextIsSelectable(true); lay.addView(tv1) local scroll=ScrollView(ctxSafe()); local tv2=TextView(ctxSafe()); tv2.setText(tostring(detalle)); tv2.setTextColor(Color.WHITE); tv2.setTextIsSelectable(true); tv2.setTextSize(11); scroll.addView(tv2); lay.addView(scroll) local btn=Button(ctxSafe()); btn.setText("Entendido"); lay.addView(btn) local d=LuaDialog(ctxSafe()); d.setView(lay); d.setCancelable(false); d.show() local l={}; function l.onClick(v) d.dismiss() end; btn.setOnClickListener(View.OnClickListener(l)) hablar(titulo) end) end
function getLength(a) local ok,len=pcall(function() local cls=luajava.bindClass("java.lang.reflect.Array") return cls.getLength(a) end) if ok then return len else return 0 end end
function listarSubdirectorios(path) local dirs={}; local f=File(path) if f.exists() and f.isDirectory() then local files=f.listFiles() if files then for i=0,getLength(files)-1 do local item=files[i] if item and item.isDirectory() then local e={} e.name=item.getName() e.path=item.getAbsolutePath() table.insert(dirs,e) end end end end return dirs end
function compressFolder(folderPath, zipFilePath) local fos=FileOutputStream(zipFilePath); local zos=ZipOutputStream(fos) local function add(file, base) local rel=file.getName(); if base then rel=file.getPath():sub(#base+2) end if file.isDirectory() then local list=file.listFiles() if list then for i=0,getLength(list)-1 do add(list[i], base or file.getPath()) end end else local ze=ZipEntry(rel); zos.putNextEntry(ze); local bis=BufferedInputStream(FileInputStream(file)); local buf=byte[4096]; local r=bis.read(buf,0,4096) while r~=-1 do zos.write(buf,0,r); r=bis.read(buf,0,4096) end bis.close(); zos.closeEntry() end end add(File(folderPath)); zos.close(); fos.close() end
function mostrarProgreso(msg) local lay=LinearLayout(ctxSafe()); lay.setPadding(30,30,30,30); local tv=TextView(ctxSafe()); tv.setText(msg); tv.setTextColor(Color.WHITE); lay.addView(tv) local d=LuaDialog(ctxSafe()); d.setView(lay); d.setCancelable(false); d.show(); return d end
function descargarYExtraerSonidos(callbackRefresco) local prog=mostrarProgreso("Descargando y extrayendo automáticamente a la carpeta...") Thread(function() local ok,err=pcall(function() crearCarpetaSonidosSiNoExiste() local url=URL(SONIDOS_URL) local conn=url.openConnection() conn.setConnectTimeout(20000) conn.setReadTimeout(20000) local input=conn.getInputStream() local fzip=File(ZIP_TEMP_SONIDOS) if fzip.exists() then fzip.delete() end local fos=FileOutputStream(fzip) local buf=byte[8192] local r=input.read(buf) while r~=-1 do fos.write(buf,0,r) r=input.read(buf) end fos.close() input.close() extraerZipSonidosAutomatico(ZIP_TEMP_SONIDOS, CARPETA_SONIDOS) pcall(function() File(ZIP_TEMP_SONIDOS).delete() end) end) postUi(function() prog.dismiss() if ok then local lay=LinearLayout(ctxSafe()); lay.setPadding(20,20,20,20) local tv=TextView(ctxSafe()); tv.setText("Sonidos extraídos correctamente en:\n"..CARPETA_SONIDOS); tv.setTextColor(Color.WHITE); lay.addView(tv) local btn=Button(ctxSafe()); btn.setText("Entendido"); lay.addView(btn) local d=LuaDialog(ctxSafe()); d.setView(lay); d.setCancelable(false); d.show() local l={}; function l.onClick(v) d.dismiss(); reproducirSonido("inicio.ogg") if callbackRefresco then callbackRefresco() end end; btn.setOnClickListener(View.OnClickListener(l)) else mostrarErrorDetallado("Error al descargar sonidos", tostring(err)) end end) end).start() end
function mostrarDialogoDescargaDeSonidos()
  local lay=LinearLayout(ctxSafe()); lay.setOrientation(LinearLayout.VERTICAL); lay.setPadding(20,20,20,20)
  local tv=TextView(ctxSafe()); tv.setText("Se necesita descargar los sonidos de la tienda para continuar con los efectos de sonido."); tv.setTextColor(Color.WHITE); lay.addView(tv)
  local fila=LinearLayout(ctxSafe()); fila.setOrientation(LinearLayout.HORIZONTAL)
  local b1=Button(ctxSafe()); b1.setText("Aceptar"); b1.setLayoutParams(LinearLayout.LayoutParams(0,-2,1))
  local b2=Button(ctxSafe()); b2.setText("Cancelar"); b2.setLayoutParams(LinearLayout.LayoutParams(0,-2,1))
  fila.addView(b1); fila.addView(b2); lay.addView(fila)
  local d=LuaDialog(ctxSafe()); d.setView(lay); d.setCancelable(false); d.show()
  local l1={}; function l1.onClick(v) d.dismiss(); descargarYExtraerSonidos(nil) end; b1.setOnClickListener(View.OnClickListener(l1))
  local l2={}; function l2.onClick(v) d.dismiss(); Toast.makeText(ctxSafe(),"Puedes descargarlos luego en Configuración > Descargar sonidos",1).show() end; b2.setOnClickListener(View.OnClickListener(l2))
end
function verificarSonidosAlIniciar() Thread(function() local falta=not existeCarpetaYSonidos() if falta then postUi(function() mostrarDialogoDescargaDeSonidos() end) else reproducirSonido("inicio.ogg") end end).start() end
function asegurarArchivosRepo(cb)
  local prog=mostrarProgreso("cargando servidor")
  Thread(function()
    local function crearSiNoExiste(pathApi, contenido)
      pcall(function()
        local c=URL("https://api.github.com/repos/"..REPO.."/contents/"..pathApi).openConnection()
        c.setRequestMethod("GET"); c.setRequestProperty("Authorization","token "..TOKEN)
        if c.getResponseCode()==404 then
          local c2=URL("https://api.github.com/repos/"..REPO.."/contents/"..pathApi).openConnection()
          c2.setRequestMethod("PUT"); c2.setRequestProperty("Authorization","token "..TOKEN); c2.setRequestProperty("Content-Type","application/json"); c2.setDoOutput(true)
          local enc=Base64.encodeToString(String(contenido).getBytes("UTF-8"),Base64.NO_WRAP)
          local body={message="Crear "..pathApi, content=enc, branch="main"}
          local os=c2.getOutputStream(); os.write(String(cjson.encode(body)).getBytes("UTF-8")); os.flush(); os.close()
        end
      end)
    end
    crearSiNoExiste("archivos.json","[]")
    crearSiNoExiste("eliminados.json","[]")
    crearSiNoExiste("descartados.json","[]")
    crearSiNoExiste("perfiles.txt","superadmin|aplicaciones company|Aplicaciones Company\n")
    crearSiNoExiste("calificaciones.json","[]")
    crearSiNoExiste("notificaciones.json","[]")
    postUi(function() prog.dismiss(); if cb then cb() end end)
  end).start()
end
function leerArchivoPorAPI(nombre) local txt=nil pcall(function() local api=URL("https://api.github.com/repos/"..REPO.."/contents/"..nombre) local c=api.openConnection(); c.setRequestMethod("GET"); c.setRequestProperty("Authorization","token "..TOKEN) if c.getResponseCode()==200 then local br=BufferedReader(InputStreamReader(c.getInputStream())); local s=""; local l=br.readLine() while l~=nil do s=s..l; l=br.readLine() end br.close() local obj=cjson.decode(s) if obj.content and obj.content~="" then txt=tostring(String(Base64.decode(obj.content,Base64.DEFAULT),"UTF-8")) end end end) return txt end
function cargarArchivos(cb)
  Thread(function()
    local txt=leerArchivoPorAPI("archivos.json") or "[]"
    local elimTxt=leerArchivoPorAPI("eliminados.json") or "[]"
    local califTxt=leerArchivoPorAPI("calificaciones.json") or "[]"
    local descarTxt=leerArchivoPorAPI("descartados.json") or "[]"
    local notifTxt=leerArchivoPorAPI("notificaciones.json") or "[]"
    postUi(function()
      local ok1,dec1=pcall(function() return cjson.decode(tostring(elimTxt)) end) if ok1 and dec1 then ELIMINADOS_CACHE=dec1 else ELIMINADOS_CACHE={} end
      local ok2,dec2=pcall(function() return cjson.decode(tostring(califTxt)) end) if ok2 and dec2 then CALIFICACIONES_CACHE=dec2 else CALIFICACIONES_CACHE={} end
      local ok3,dec3=pcall(function() return cjson.decode(tostring(descarTxt)) end) if ok3 and dec3 then DESCARTADOS_CACHE=dec3 else DESCARTADOS_CACHE={} end
      local ok4,dec4=pcall(function() return cjson.decode(tostring(notifTxt)) end) if ok4 and dec4 then NOTIFICACIONES_CACHE=dec4 else NOTIFICACIONES_CACHE={} end
      local txtLimpio=tostring(txt):gsub("%s+","")
      local estaVacio = (txtLimpio=="" or txtLimpio=="[]" or txtLimpio=="null" or #txtLimpio<5)
      local ok,datos=pcall(function() return cjson.decode(txt) end)
      local todo={}
      if ok and datos then
        if datos.nombre then datos={datos} end
        for _,it in ipairs(datos) do
          if it.nombre then
            local bloqueado=false for _,elim in ipairs(ELIMINADOS_CACHE) do if elim:lower()==it.nombre:lower() then bloqueado=true; break end end
            if not bloqueado then
              it.categoria=detectarCategoriaCorrecta(it.nombre, it.descripcion)
              table.insert(todo,it)
            end
          end
        end
      end
      ARCHIVOS_CACHE=todo
      hablar("conectando")
      if (#todo==0 or estaVacio) then
        YA_RECUPERADO=true
        reconstruirDesdeReleases(true)
      else
        if cb then cb() end
        verificarNuevasNotificacionesAlEntrar()
      end
    end)
  end).start()
end
function verificarSiDescartado() if ROL=="invitado" then return false end for _,u in ipairs(DESCARTADOS_CACHE) do if u:lower()==MI_USUARIO:lower() or MI_USUARIO:lower():find(u:lower(),1,true) then return true end end return false end
function mostrarDialogoDescartado() local lay=LinearLayout(ctxSafe()); lay.setOrientation(LinearLayout.VERTICAL); lay.setPadding(30,30,30,30); lay.setBackgroundColor(Color.parseColor("#FF1A1A1A")) local tv=TextView(ctxSafe()); tv.setText("Fuiste descartado\n¡Gracias por estar en la tienda!"); tv.setTextColor(Color.WHITE); tv.setTextSize(18); tv.setGravity(Gravity.CENTER); lay.addView(tv) local d=LuaDialog(ctxSafe()); d.setView(lay); d.setCancelable(false); d.show() local btn=Button(ctxSafe()); btn.setText("SALIR"); btn.setBackgroundColor(Color.parseColor("#FF222222")); btn.setTextColor(Color.WHITE); lay.addView(btn) local l={}; function l.onClick(v) d.dismiss(); if activity then activity.finish() end end; btn.setOnClickListener(View.OnClickListener(l)) end
function mostrarDialogoUsuarioNoExiste()
  reproducirSonido("error.ogg")
  local lay=LinearLayout(ctxSafe()); lay.setPadding(20,20,20,20)
  local tv=TextView(ctxSafe()); tv.setText("Error, este usuario no se encuentra. Esto solo es para los administradores"); tv.setTextColor(Color.WHITE); lay.addView(tv)
  local btn=Button(ctxSafe()); btn.setText("Entendido"); lay.addView(btn)
  local d=LuaDialog(ctxSafe()); d.setView(lay); d.setCancelable(false); d.show()
  local l={}; function l.onClick(v) d.dismiss(); vibrar(); mostrarLogin() end; btn.setOnClickListener(View.OnClickListener(l))
  hablar("Error, este usuario no se encuentra. Esto solo es para los administradores")
end
function verificarPerfil(cb)
  local progVer=mostrarProgreso("verificando")
  Thread(function()
    local body=leerArchivoPorAPI("perfiles.txt") or "superadmin|aplicaciones company|Aplicaciones Company\n"
    postUi(function()
      progVer.dismiss()
      PERFILES_CACHE={}
      local encontrado=false
      if ROL~="invitado" then
        ROL="visitante"
        MI_NOMBRE_PUBLICO=MI_USUARIO
        for line in body:gmatch("[^\n]+") do
          if line:find("|") and not line:match("^#") then
            local rol,usr,pub=line:match("^(.-)|(.-)|(.-)$")
            if rol and usr and pub then
              rol=rol:gsub("^%s+",""):gsub("%s+$",""):lower()
              usr=usr:gsub("^%s+",""):gsub("%s+$",""):lower()
              pub=pub:gsub("^%s+",""):gsub("%s+$","")
              if pub=="" then pub=usr end
              local item={} item.rol=rol; item.usuario=usr; item.nombre=pub; table.insert(PERFILES_CACHE,item)
              if usr==MI_USUARIO or pub:lower()==MI_USUARIO:lower() then ROL=rol; MI_NOMBRE_PUBLICO=pub; MI_USUARIO=usr; encontrado=true end
            end
          end
        end
      else
        encontrado=true
        for line in body:gmatch("[^\n]+") do
          if line:find("|") and not line:match("^#") then
            local rol,usr,pub=line:match("^(.-)|(.-)|(.-)$")
            if rol and usr and pub then
              rol=rol:gsub("^%s+",""):gsub("%s+$",""):lower()
              usr=usr:gsub("^%s+",""):gsub("%s+$",""):lower()
              pub=pub:gsub("^%s+",""):gsub("%s+$","")
              if pub=="" then pub=usr end
              local item={} item.rol=rol; item.usuario=usr; item.nombre=pub; table.insert(PERFILES_CACHE,item)
            end
          end
        end
      end
      if #PERFILES_CACHE==0 then
        local item={} item.rol="superadmin" item.usuario="aplicaciones company" item.nombre="Aplicaciones Company" table.insert(PERFILES_CACHE,item)
      end
      if not encontrado then
        local prefs=obtenerPrefs()
        local ed=prefs.edit(); ed.putBoolean("guardar_sesion",false); ed.remove("usuario_guardado"); ed.remove("rol_guardado"); ed.remove("nombre_guardado"); ed.apply()
        mostrarDialogoUsuarioNoExiste()
        return
      end
      cargarArchivos(function()
        if verificarSiDescartado() then mostrarDialogoDescartado() else if cb then cb() end end
      end)
    end)
  end).start()
end
function agregarAdministradorGitHub(rol, usuarioInterno, nombrePublico, cb) local usuarioLower=usuarioInterno:lower():gsub("^%s+",""):gsub("%s+$","") local prog=mostrarProgreso("Agregando admin...") Thread(function() local ok,err=pcall(function() local apiDesc="https://api.github.com/repos/"..REPO.."/contents/descartados.json" local cD=URL(apiDesc).openConnection(); cD.setRequestMethod("GET"); cD.setRequestProperty("Authorization","token "..TOKEN) local shaD=""; local listaD={} if cD.getResponseCode()==200 then local br=BufferedReader(InputStreamReader(cD.getInputStream())); local s=""; local l=br.readLine() while l~=nil do s=s..l; l=br.readLine() end br.close() local obj=cjson.decode(s); shaD=obj.sha or "" if obj.content and obj.content~="" then local dec=tostring(String(Base64.decode(obj.content,Base64.DEFAULT),"UTF-8")); local dl=cjson.decode(dec); if dl then listaD=dl end end end local nuevaDesc={} for _,u in ipairs(listaD) do if u:lower()~=usuarioLower then table.insert(nuevaDesc,u) end end DESCARTADOS_CACHE=nuevaDesc local jD=cjson.encode(nuevaDesc); local encD=Base64.encodeToString(String(jD).getBytes("UTF-8"),Base64.NO_WRAP) local putD=URL(apiDesc).openConnection(); putD.setRequestMethod("PUT"); putD.setRequestProperty("Authorization","token "..TOKEN); putD.setRequestProperty("Content-Type","application/json"); putD.setDoOutput(true) local bodyD={message="Rehabilitar "..usuarioLower, content=encD, branch="main"}; if shaD~="" then bodyD.sha=shaD end local osD=putD.getOutputStream(); osD.write(String(cjson.encode(bodyD)).getBytes("UTF-8")); osD.flush(); osD.close(); putD.getResponseCode() local api="https://api.github.com/repos/"..REPO.."/contents/perfiles.txt" local c=URL(api).openConnection(); c.setRequestMethod("GET"); c.setRequestProperty("Authorization","token "..TOKEN) local sha=""; local contenido="" if c.getResponseCode()==200 then local br=BufferedReader(InputStreamReader(c.getInputStream())); local s=""; local l=br.readLine() while l~=nil do s=s..l; l=br.readLine() end br.close() local obj=cjson.decode(s); sha=obj.sha or "" if obj.content and obj.content~="" then contenido=tostring(String(Base64.decode(obj.content,Base64.DEFAULT),"UTF-8")) end end local yaExiste=false for line in contenido:gmatch("[^\n]+") do local _,u,_=line:match("^(.-)|(.-)|(.-)$") if u and u:gsub("%s+",""):lower()==usuarioLower then yaExiste=true; break end end if not yaExiste then local nuevaLinea=rol:lower().."|"..usuarioLower.."|"..nombrePublico.."\n" contenido=contenido..nuevaLinea end local enc=Base64.encodeToString(String(contenido).getBytes("UTF-8"),Base64.NO_WRAP) local put=URL(api).openConnection(); put.setRequestMethod("PUT"); put.setRequestProperty("Authorization","token "..TOKEN); put.setRequestProperty("Content-Type","application/json"); put.setDoOutput(true) local body={message="Agregar admin "..usuarioLower, content=enc, branch="main"}; if sha~="" then body.sha=sha end local os=put.getOutputStream(); os.write(String(cjson.encode(body)).getBytes("UTF-8")); os.flush(); os.close(); put.getResponseCode() postUi(function() prog.dismiss() local lay=LinearLayout(ctxSafe()); lay.setOrientation(LinearLayout.VERTICAL); lay.setPadding(20,20,20,20) local tv=TextView(ctxSafe()); tv.setText("¡Nuevo perfil agregado!\n¿Deseas actualizar?"); tv.setTextColor(Color.WHITE); tv.setTextSize(16); tv.setGravity(Gravity.CENTER); lay.addView(tv) local fila=LinearLayout(ctxSafe()); fila.setOrientation(LinearLayout.HORIZONTAL) local bNo=Button(ctxSafe()); bNo.setText("Cancelar"); bNo.setLayoutParams(LinearLayout.LayoutParams(0,-2,1)) local bSi=Button(ctxSafe()); bSi.setText("Aceptar"); bSi.setLayoutParams(LinearLayout.LayoutParams(0,-2,1)) fila.addView(bNo); fila.addView(bSi); lay.addView(fila) local d=LuaDialog(ctxSafe()); d.setView(lay); d.setCancelable(false); d.show() local lNo={}; function lNo.onClick(v) d.dismiss() end; bNo.setOnClickListener(View.OnClickListener(lNo)) local lSi={}; function lSi.onClick(v) d.dismiss(); verificarPerfil(function() mostrarPerfiles() end) end; bSi.setOnClickListener(View.OnClickListener(lSi)) if cb then cb() end end) end) if not ok then postUi(function() prog.dismiss(); mostrarErrorDetallado("ERROR AGREGAR ADMIN", tostring(err)) end) end end).start() end
function descartarUsuarioGitHub(usuarioInterno, cb) local usuarioLower=usuarioInterno:lower():gsub("^%s+",""):gsub("%s+$","") if usuarioLower=="aplicaciones company" then Toast.makeText(ctxSafe(),"No puedes descartarte a ti mismo",Toast.LENGTH_LONG).show(); return end local prog=mostrarProgreso("Descartando "..usuarioInterno.." del servidor...") Thread(function() local ok,err=pcall(function() local apiDesc="https://api.github.com/repos/"..REPO.."/contents/descartados.json" local c=URL(apiDesc).openConnection(); c.setRequestMethod("GET"); c.setRequestProperty("Authorization","token "..TOKEN) local shaD=""; local lista={} if c.getResponseCode()==200 then local br=BufferedReader(InputStreamReader(c.getInputStream())); local s=""; local l=br.readLine() while l~=nil do s=s..l; l=br.readLine() end br.close() local obj=cjson.decode(s); shaD=obj.sha or "" if obj.content and obj.content~="" then local dec=tostring(String(Base64.decode(obj.content,Base64.DEFAULT),"UTF-8")); local dl=cjson.decode(dec); if dl then lista=dl end end end local ya=false for _,u in ipairs(lista) do if u:lower()==usuarioLower then ya=true; break end end if not ya then table.insert(lista, usuarioLower) end DESCARTADOS_CACHE=lista local jD=cjson.encode(lista); local encD=Base64.encodeToString(String(jD).getBytes("UTF-8"),Base64.NO_WRAP) local putD=URL(apiDesc).openConnection(); putD.setRequestMethod("PUT"); putD.setRequestProperty("Authorization","token "..TOKEN); putD.setRequestProperty("Content-Type","application/json"); putD.setDoOutput(true) local bodyD={message="Descartar "..usuarioLower, content=encD, branch="main"}; if shaD~="" then bodyD.sha=shaD end local osD=putD.getOutputStream(); osD.write(String(cjson.encode(bodyD)).getBytes("UTF-8")); osD.flush(); osD.close(); putD.getResponseCode() local apiPerf="https://api.github.com/repos/"..REPO.."/contents/perfiles.txt" local c2=URL(apiPerf).openConnection(); c2.setRequestMethod("GET"); c2.setRequestProperty("Authorization","token "..TOKEN) local shaP=""; local contenido="" if c2.getResponseCode()==200 then local br=BufferedReader(InputStreamReader(c2.getInputStream())); local s=""; local l=br.readLine() while l~=nil do s=s..l; l=br.readLine() end br.close() local obj=cjson.decode(s); shaP=obj.sha or "" if obj.content and obj.content~="" then contenido=tostring(String(Base64.decode(obj.content,Base64.DEFAULT),"UTF-8")) end end local nuevoCont="" for line in contenido:gmatch("[^\n]+") do if not line:lower():find(usuarioLower,1,true) then nuevoCont=nuevoCont..line.."\n" else if line:lower():find("aplicaciones company",1,true) then nuevoCont=nuevoCont..line.."\n" end end end if nuevoCont=="" then nuevoCont="superadmin|aplicaciones company|Aplicaciones Company\n" end local encP=Base64.encodeToString(String(nuevoCont).getBytes("UTF-8"),Base64.NO_WRAP) local putP=URL(apiPerf).openConnection(); putP.setRequestMethod("PUT"); putP.setRequestProperty("Authorization","token "..TOKEN); putP.setRequestProperty("Content-Type","application/json"); putP.setDoOutput(true) local bodyP={message="Descarte "..usuarioLower, content=encP, branch="main"}; if shaP~="" then bodyP.sha=shaP end local osP=putP.getOutputStream(); osP.write(String(cjson.encode(bodyP)).getBytes("UTF-8")); osP.flush(); osP.close(); putP.getResponseCode() local apiArch="https://api.github.com/repos/"..REPO.."/contents/archivos.json" local c3=URL(apiArch).openConnection(); c3.setRequestMethod("GET"); c3.setRequestProperty("Authorization","token "..TOKEN) local shaA=""; local listaArch={} if c3.getResponseCode()==200 then local br=BufferedReader(InputStreamReader(c3.getInputStream())); local s=""; local l=br.readLine() while l~=nil do s=s..l; l=br.readLine() end br.close() local obj=cjson.decode(s); shaA=obj.sha or "" if obj.content and obj.content~="" then local dec=tostring(String(Base64.decode(obj.content,Base64.DEFAULT),"UTF-8")); local dl=cjson.decode(dec); if dl then listaArch=dl end end end local nuevaLista={} for _,it in ipairs(listaArch) do if (it.autor_lower or ""):lower()~=usuarioLower then table.insert(nuevaLista, it) end end ARCHIVOS_CACHE=nuevaLista local jA=cjson.encode(nuevaLista); local encA=Base64.encodeToString(String(jA).getBytes("UTF-8"),Base64.NO_WRAP) local putA=URL(apiArch).openConnection(); putA.setRequestMethod("PUT"); putA.setRequestProperty("Authorization","token "..TOKEN); putA.setRequestProperty("Content-Type","application/json"); putA.setDoOutput(true) local bodyA={message="Borrar archivos de "..usuarioLower, content=encA, branch="main"}; if shaA~="" then bodyA.sha=shaA end local osA=putA.getOutputStream(); osA.write(String(cjson.encode(bodyA)).getBytes("UTF-8")); osA.flush(); osA.close(); putA.getResponseCode() local nuevaCache={} for _,p in ipairs(PERFILES_CACHE) do if p.usuario:lower()~=usuarioLower then table.insert(nuevaCache,p) end end PERFILES_CACHE=nuevaCache postUi(function() prog.dismiss() Toast.makeText(ctxSafe(),"Usuario borrado del servidor",Toast.LENGTH_LONG).show() verificarPerfil(function() mostrarListaAdminsParaDescartar() end) if cb then cb() end end) end) if not ok then postUi(function() prog.dismiss(); mostrarErrorDetallado("ERROR DESCARTE", tostring(err)) end) end end).start() end
function subirAGitHub(tipoCat,filePath,desc,tuto,esEdicion,nombreOriginal,cbExito) local prog=mostrarProgreso(esEdicion and "Actualizando..." or "Subiendo a "..tipoCat.."...") Thread(function() local function leerRespuesta(conn) local ok,res=pcall(function() local stream=nil if conn.getResponseCode()>=400 then stream=conn.getErrorStream() else stream=conn.getInputStream() end if not stream then return "sin body" end local br=BufferedReader(InputStreamReader(stream)) local sb="" local l=br.readLine() while l~=nil do sb=sb..l.."\n"; l=br.readLine() end br.close() return sb end) if ok then return res else return "error" end end local ok,err=pcall(function() local autorLowerFinal=MI_USUARIO:lower() local autorPublicoFinal=MI_NOMBRE_PUBLICO if ROL=="superadmin" and perfilActual and perfilActual:lower()~="aplicaciones company" then autorLowerFinal=obtenerUsuarioLowerDePerfil(perfilActual) autorPublicoFinal=perfilActual end local fileObj=nil; if filePath then fileObj=File(filePath) end; local fileName=nombreOriginal or "archivo.zip" if not esEdicion and fileObj then fileName=fileObj.getName() end local downloadUrl=nil if esEdicion then if fileObj then fileName=nombreOriginal local url=URL("https://api.github.com/repos/"..REPO.."/releases?per_page=100"); local conn=url.openConnection(); conn.setRequestProperty("Authorization","token "..TOKEN) local br=BufferedReader(InputStreamReader(conn.getInputStream())); local s=""; local l=br.readLine() while l~=nil do s=s..l; l=br.readLine() end br.close(); local releases=cjson.decode(s) local releaseEncontrado=nil; local assetId=nil; local uploadUrl=nil for _,rel in ipairs(releases) do if rel.assets then for _,asset in ipairs(rel.assets) do if asset.name:lower()==nombreOriginal:lower() then releaseEncontrado=rel; assetId=asset.id; uploadUrl=rel.upload_url; break end end end if releaseEncontrado then break end end if releaseEncontrado and assetId and uploadUrl then local delUrl=URL("https://api.github.com/repos/"..REPO.."/releases/assets/"..assetId) local delConn=delUrl.openConnection(); delConn.setRequestMethod("DELETE"); delConn.setRequestProperty("Authorization","token "..TOKEN); delConn.getResponseCode() local upUrlBase=uploadUrl:gsub("{%?name,label}","").."?name="..fileName local connUp=URL(upUrlBase).openConnection(); connUp.setRequestMethod("POST"); connUp.setRequestProperty("Authorization","token "..TOKEN); connUp.setRequestProperty("Content-Type","application/octet-stream"); connUp.setDoOutput(true) local fis=FileInputStream(fileObj); local osUp=connUp.getOutputStream(); local buf=byte[4096]; local r=fis.read(buf,0,4096) while r~=-1 do osUp.write(buf,0,r); r=fis.read(buf,0,4096) end fis.close(); osUp.flush(); osUp.close() local codeUp=connUp.getResponseCode(); local respUp=leerRespuesta(connUp); if codeUp~=201 then error("FALLO REEMPLAZO ASSET "..codeUp.."\n"..respUp) end local asset=cjson.decode(respUp); downloadUrl=asset.browser_download_url local bodyConAutor="["..tipoCat.."] "..autorLowerFinal.."|"..autorPublicoFinal.."|"..desc local patchUrl=URL("https://api.github.com/repos/"..REPO.."/releases/"..releaseEncontrado.id) local patchConn=patchUrl.openConnection(); patchConn.setRequestMethod("PATCH"); patchConn.setRequestProperty("Authorization","token "..TOKEN); patchConn.setRequestProperty("Content-Type","application/json"); patchConn.setDoOutput(true) local patchBody=cjson.encode({body=bodyConAutor}); local osP=patchConn.getOutputStream(); osP.write(String(patchBody).getBytes("UTF-8")); osP.flush(); osP.close(); patchConn.getResponseCode() else for _,it in ipairs(ARCHIVOS_CACHE) do if it.nombre:lower()==nombreOriginal:lower() then downloadUrl=it.url; break end end end else fileName=nombreOriginal end elseif fileObj and not esEdicion then fileName=fileObj.getName(); local tag="v"..os.time(); local relUrl=URL("https://api.github.com/repos/"..REPO.."/releases"); local conn=relUrl.openConnection(); conn.setRequestMethod("POST"); conn.setRequestProperty("Authorization","token "..TOKEN); conn.setRequestProperty("Content-Type","application/json"); conn.setDoOutput(true) local bodyConAutor="["..tipoCat.."] "..autorLowerFinal.."|"..autorPublicoFinal.."|"..desc local bodyTable={} bodyTable.tag_name=tag; bodyTable.name="Release "..fileName; bodyTable.body=bodyConAutor; bodyTable.draft=false; bodyTable.prerelease=false; local body=cjson.encode(bodyTable); local os=conn.getOutputStream(); os.write(String(body).getBytes("UTF-8")); os.flush(); os.close() local code=conn.getResponseCode(); local resp=leerRespuesta(conn); if code~=201 then error("FALLO RELEASE "..code.."\n"..resp) end local data=cjson.decode(resp); local upUrl=data.upload_url:gsub("{%?name,label}","").."?name="..fileName local connUp=URL(upUrl).openConnection(); connUp.setRequestMethod("POST"); connUp.setRequestProperty("Authorization","token "..TOKEN); connUp.setRequestProperty("Content-Type","application/octet-stream"); connUp.setDoOutput(true) local fis=FileInputStream(fileObj); local osUp=connUp.getOutputStream(); local buf=byte[4096]; local r=fis.read(buf,0,4096) while r~=-1 do osUp.write(buf,0,r); r=fis.read(buf,0,4096) end fis.close(); osUp.flush(); osUp.close() local codeUp=connUp.getResponseCode(); local respUp=leerRespuesta(connUp); if codeUp~=201 then error("FALLO ASSET "..codeUp.."\n"..respUp) end local asset=cjson.decode(respUp); downloadUrl=asset.browser_download_url end local jsonUrl=URL("https://api.github.com/repos/"..REPO.."/contents/archivos.json"); local connGet=jsonUrl.openConnection(); connGet.setRequestMethod("GET"); connGet.setRequestProperty("Authorization","token "..TOKEN); local sha=nil; local lista={}; local codeGet=connGet.getResponseCode() if codeGet==200 then local br=BufferedReader(InputStreamReader(connGet.getInputStream())); local s=""; local l=br.readLine() while l~=nil do s=s..l; l=br.readLine() end br.close(); local obj=cjson.decode(s); sha=obj.sha; if obj.content then local decBytes=Base64.decode(obj.content,Base64.DEFAULT); local decStr=tostring(String(decBytes,"UTF-8")); local dl=cjson.decode(decStr); if dl then lista=dl end end end local nuevoObj=nil if esEdicion then for k,it in ipairs(lista) do if it.nombre:lower()==nombreOriginal:lower() then it.descripcion=desc; it.categoria=tipoCat; if downloadUrl then it.url=downloadUrl end; it.tutorial=tuto or ""; it.fecha=os.time(); nuevoObj=it; break end end else local nuevo={} nuevo.categoria=tipoCat; nuevo.nombre=fileName; nuevo.autor=autorPublicoFinal; nuevo.autor_lower=autorLowerFinal; nuevo.descripcion=desc; nuevo.tutorial=tuto or ""; nuevo.url=downloadUrl; nuevo.fecha=os.time(); nuevo.descargas=0; table.insert(lista,nuevo); nuevoObj=nuevo end if nuevoObj then local ex=false for k,it in ipairs(ARCHIVOS_CACHE) do if it.nombre:lower()==nuevoObj.nombre:lower() then ARCHIVOS_CACHE[k]=nuevoObj; ex=true; break end end if not ex then table.insert(ARCHIVOS_CACHE,nuevoObj) end end local newJson=cjson.encode(lista); local enc=Base64.encodeToString(String(newJson).getBytes("UTF-8"),Base64.NO_WRAP); local connPut=jsonUrl.openConnection(); connPut.setRequestMethod("PUT"); connPut.setRequestProperty("Authorization","token "..TOKEN); connPut.setRequestProperty("Content-Type","application/json"); connPut.setDoOutput(true) local putBody={} putBody.content=enc; putBody.branch="main"; putBody.message=(esEdicion and "Actualizar " or "Agregar ")..fileName.." a "..autorPublicoFinal; if sha then putBody.sha=sha end; local osPut=connPut.getOutputStream(); osPut.write(String(cjson.encode(putBody)).getBytes("UTF-8")); osPut.flush(); osPut.close() postUi(function() prog.dismiss(); Toast.makeText(ctxSafe(), esEdicion and "Actualizado" or "Subido a "..autorPublicoFinal.." y visible solo en su perfil",Toast.LENGTH_LONG).show(); if cbExito then cbExito() end end) end) if not ok then postUi(function() prog.dismiss(); mostrarErrorDetallado("ERROR SUBIR", tostring(err)) end) end end).start() end
function incrementarDescarga(item) Thread(function() pcall(function() local api="https://api.github.com/repos/"..REPO.."/contents/archivos.json" local c=URL(api).openConnection(); c.setRequestMethod("GET"); c.setRequestProperty("Authorization","token "..TOKEN); if c.getResponseCode()~=200 then return end local br=BufferedReader(InputStreamReader(c.getInputStream())); local s=""; local l=br.readLine() while l~=nil do s=s..l; l=br.readLine() end br.close(); local obj=cjson.decode(s); local sha=obj.sha local dec=tostring(String(Base64.decode(obj.content,Base64.DEFAULT),"UTF-8")); local lista=cjson.decode(dec) for k,it in ipairs(lista) do if it.nombre:lower()==item.nombre:lower() then it.descargas=(it.descargas or 0)+1; break end end local newJson=cjson.encode(lista); local enc=Base64.encodeToString(String(newJson).getBytes("UTF-8"),Base64.NO_WRAP) local put=URL(api).openConnection(); put.setRequestMethod("PUT"); put.setRequestProperty("Authorization","token "..TOKEN); put.setRequestProperty("Content-Type","application/json"); put.setDoOutput(true) local body={message="Descarga "..item.nombre, content=enc, branch="main", sha=sha}; local os=put.getOutputStream(); os.write(String(cjson.encode(body)).getBytes("UTF-8")); os.flush(); os.close() end) end).start() end
function reconstruirDesdeReleases(esAuto)
  local prog=mostrarProgreso("Recuperando lanzamientos...")
  Thread(function()
    local ok,err=pcall(function()
      local mapaAutores={}
      for _,it in ipairs(ARCHIVOS_CACHE) do if it.nombre then mapaAutores[it.nombre:lower()]={autor=it.autor, autor_lower=it.autor_lower} end end
      local todosReleases={}
      for pagina=1,10 do
        local url=URL("https://api.github.com/repos/"..REPO.."/releases?per_page=100&page="..pagina)
        local conn=url.openConnection()
        conn.setRequestProperty("Authorization","token "..TOKEN)
        conn.setConnectTimeout(15000)
        conn.setReadTimeout(15000)
        if conn.getResponseCode()~=200 then break end
        local br=BufferedReader(InputStreamReader(conn.getInputStream()))
        local s=""; local l=br.readLine() while l~=nil do s=s..l; l=br.readLine() end br.close()
        local releases=cjson.decode(s)
        if not releases or #releases==0 then break end
        for _,r in ipairs(releases) do table.insert(todosReleases,r) end
        if #releases<100 then break end
      end
      local todo={}
      local nombresVistos={}
      for _,rel in ipairs(todosReleases) do
        if rel.assets then
          for _,asset in ipairs(rel.assets) do
            local bodyRaw=rel.body or ""
            local cat=detectarCategoriaCorrecta(asset.name, bodyRaw)
            local autorFinal="Aplicaciones Company"
            local autorLowerFinal="aplicaciones company"
            local descFinal=bodyRaw:gsub("%[.-%]","")
            local limpio=bodyRaw:gsub("^%[.-%]%s*","")
            if limpio:find("|") then
              local aLower,aPub,d=limpio:match("^(.-)|(.-)|(.*)$")
              if aLower and aPub then
                autorLowerFinal=aLower:gsub("^%s+",""):gsub("%s+$",""):lower()
                autorFinal=aPub:gsub("^%s+",""):gsub("%s+$","")
                descFinal=d
              end
            else
              if mapaAutores[asset.name:lower()] then autorFinal=mapaAutores[asset.name:lower()].autor autorLowerFinal=mapaAutores[asset.name:lower()].autor_lower end
            end
            local nombreFinal=asset.name
            if nombresVistos[asset.name:lower()] then
              local base=asset.name:match("(.+)%..+") or asset.name
              local ext=asset.name:match("%.(.+)$") or "zip"
              nombreFinal=base.."_v"..(nombresVistos[asset.name:lower()]+1).."."..ext
            end
            nombresVistos[asset.name:lower()]=(nombresVistos[asset.name:lower()] or 0)+1
            local nuevo={}
            nuevo.categoria=cat; nuevo.nombre=nombreFinal; nuevo.autor=autorFinal; nuevo.autor_lower=autorLowerFinal; nuevo.descripcion=descFinal; nuevo.url=asset.browser_download_url; nuevo.fecha=os.time(); nuevo.descargas=asset.download_count or 0
            table.insert(todo,nuevo)
          end
        end
      end
      local api="https://api.github.com/repos/"..REPO.."/contents/archivos.json"
      local c=URL(api).openConnection(); c.setRequestMethod("GET"); c.setRequestProperty("Authorization","token "..TOKEN)
      local sha=nil; if c.getResponseCode()==200 then local br=BufferedReader(InputStreamReader(c.getInputStream())); local s2=""; local l=br.readLine() while l~=nil do s2=s2..l; l=br.readLine() end br.close(); local obj=cjson.decode(s2); sha=obj.sha end
      local j=cjson.encode(todo); local enc=Base64.encodeToString(String(j).getBytes("UTF-8"),Base64.NO_WRAP)
      local put=URL(api).openConnection(); put.setRequestMethod("PUT"); put.setRequestProperty("Authorization","token "..TOKEN); put.setRequestProperty("Content-Type","application/json"); put.setDoOutput(true)
      local body={} body.message="Recuperar "..#todo.." de "..#todosReleases; body.content=enc; body.branch="main"; if sha then body.sha=sha end
      local os=put.getOutputStream(); os.write(String(cjson.encode(body)).getBytes("UTF-8")); os.flush(); os.close()
      postUi(function()
        prog.dismiss()
        ARCHIVOS_CACHE=todo
        YA_RECUPERADO=false
        if mainDialog==nil or listLayout==nil then
          mostrarInterfaz()
        else
          Toast.makeText(ctxSafe(),"Recursos restaurados: "..#todo,Toast.LENGTH_SHORT).show()
          mostrarPerfiles()
        end
        verificarNuevasNotificacionesAlEntrar()
      end)
    end)
    if not ok then postUi(function() prog.dismiss(); YA_RECUPERADO=false; mostrarErrorDetallado("ERROR RECUPERAR", tostring(err)) end) end
  end).start()
end
function eliminarComplementoGitHub(archivoObj,cb) if ROL=="admin" then if (archivoObj.autor_lower or ""):lower()~=MI_USUARIO:lower() then Toast.makeText(ctxSafe(),"No puedes eliminar archivos de otros",Toast.LENGTH_LONG).show() return end end local prog=mostrarProgreso("Eliminando del servidor y de Releases...") Thread(function() local ok,err=pcall(function() local api="https://api.github.com/repos/"..REPO.."/contents/archivos.json" local c=URL(api).openConnection(); c.setRequestMethod("GET"); c.setRequestProperty("Authorization","token "..TOKEN); local sha=nil; local lista={} if c.getResponseCode()==200 then local br=BufferedReader(InputStreamReader(c.getInputStream())); local s=""; local l=br.readLine() while l~=nil do s=s..l; l=br.readLine() end br.close(); local obj=cjson.decode(s); sha=obj.sha; if obj.content then local dec=tostring(String(Base64.decode(obj.content,Base64.DEFAULT),"UTF-8")); local dl=cjson.decode(dec); if dl then lista=dl end end end local nueva={} for _,it in ipairs(lista) do if not (it.nombre:lower()==archivoObj.nombre:lower()) then table.insert(nueva,it) end end local newJson=cjson.encode(nueva); local enc=Base64.encodeToString(String(newJson).getBytes("UTF-8"),Base64.NO_WRAP); local put=URL(api).openConnection(); put.setRequestMethod("PUT"); put.setRequestProperty("Authorization","token "..TOKEN); put.setRequestProperty("Content-Type","application/json"); put.setDoOutput(true); local body={message="Eliminar "..archivoObj.nombre, content=enc, branch="main", sha=sha}; local os=put.getOutputStream(); os.write(String(cjson.encode(body)).getBytes("UTF-8")); os.flush(); os.close() local eApi="https://api.github.com/repos/"..REPO.."/contents/eliminados.json"; local eC=URL(eApi).openConnection(); eC.setRequestMethod("GET"); eC.setRequestProperty("Authorization","token "..TOKEN); local eSha=nil; local listaElim={} if eC.getResponseCode()==200 then local br=BufferedReader(InputStreamReader(eC.getInputStream())); local s=""; local l=br.readLine() while l~=nil do s=s..l; l=br.readLine() end br.close(); local obj=cjson.decode(s); eSha=obj.sha; if obj.content then local dec=tostring(String(Base64.decode(obj.content,Base64.DEFAULT),"UTF-8")); local dl=cjson.decode(dec); if dl then listaElim=dl end end end local ya=false for _,n in ipairs(listaElim) do if n:lower()==archivoObj.nombre:lower() then ya=true; break end end if not ya then table.insert(listaElim,archivoObj.nombre) end ELIMINADOS_CACHE=listaElim local eJson=cjson.encode(listaElim); local eEnc=Base64.encodeToString(String(eJson).getBytes("UTF-8"),Base64.NO_WRAP); local ePut=URL(eApi).openConnection(); ePut.setRequestMethod("PUT"); ePut.setRequestProperty("Authorization","token "..TOKEN); ePut.setRequestProperty("Content-Type","application/json"); ePut.setDoOutput(true); local eBody={message="Bloquear "..archivoObj.nombre, content=eEnc, branch="main", sha=eSha}; local osE=ePut.getOutputStream(); osE.write(String(cjson.encode(eBody)).getBytes("UTF-8")); osE.flush(); osE.close() pcall(function() local url=URL("https://api.github.com/repos/"..REPO.."/releases?per_page=100"); local conn=url.openConnection(); conn.setRequestProperty("Authorization","token "..TOKEN) local br=BufferedReader(InputStreamReader(conn.getInputStream())); local s=""; local l=br.readLine() while l~=nil do s=s..l; l=br.readLine() end br.close(); local releases=cjson.decode(s) for _,rel in ipairs(releases) do if rel.assets then for _,asset in ipairs(rel.assets) do if asset.name:lower()==archivoObj.nombre:lower() then local delUrl=URL("https://api.github.com/repos/"..REPO.."/releases/"..rel.id) local delConn=delUrl.openConnection(); delConn.setRequestMethod("DELETE"); delConn.setRequestProperty("Authorization","token "..TOKEN); delConn.getResponseCode() break end end end end end) for k,it in ipairs(ARCHIVOS_CACHE) do if it.nombre:lower()==archivoObj.nombre:lower() then table.remove(ARCHIVOS_CACHE,k); break end end postUi(function() prog.dismiss(); Toast.makeText(ctxSafe(),"Eliminado del servidor y de Lanzamientos",Toast.LENGTH_LONG).show(); if cb then cb() end end) end) if not ok then postUi(function() prog.dismiss(); mostrarErrorDetallado("ERROR ELIMINAR", tostring(err)) end) end end).start() end
function enviarNotificacionGitHub(titulo, mensaje) if ROL~="superadmin" and ROL~="admin" then Toast.makeText(ctxSafe(),"Solo propietario y administradores pueden enviar avisos",Toast.LENGTH_LONG).show() return end if titulo=="" or mensaje=="" then Toast.makeText(ctxSafe(),"Llena titulo y mensaje",Toast.LENGTH_SHORT).show(); return end local prog=mostrarProgreso("Enviando aviso...") Thread(function() local ok,err=pcall(function() local api="https://api.github.com/repos/"..REPO.."/contents/notificaciones.json" local c=URL(api).openConnection(); c.setRequestMethod("GET"); c.setRequestProperty("Authorization","token "..TOKEN) local sha=""; local lista={} if c.getResponseCode()==200 then local br=BufferedReader(InputStreamReader(c.getInputStream())); local s=""; local l=br.readLine() while l~=nil do s=s..l; l=br.readLine() end br.close() local obj=cjson.decode(s); sha=obj.sha or "" if obj.content and obj.content~="" then local dec=tostring(String(Base64.decode(obj.content,Base64.DEFAULT),"UTF-8")); local dl=cjson.decode(dec); if dl then lista=dl end end end local nuevo={} nuevo.id=os.time()..math.random(100,999); nuevo.titulo=titulo; nuevo.mensaje=mensaje; nuevo.autor=MI_NOMBRE_PUBLICO; nuevo.autor_lower=MI_USUARIO; nuevo.fecha=os.time() table.insert(lista,1,nuevo) NOTIFICACIONES_CACHE=lista local j=cjson.encode(lista); local enc=Base64.encodeToString(String(j).getBytes("UTF-8"),Base64.NO_WRAP) local put=URL(api).openConnection(); put.setRequestMethod("PUT"); put.setRequestProperty("Authorization","token "..TOKEN); put.setRequestProperty("Content-Type","application/json"); put.setDoOutput(true) local body={message="Aviso "..titulo, content=enc, branch="main"}; if sha~="" then body.sha=sha end local os=put.getOutputStream(); os.write(String(cjson.encode(body)).getBytes("UTF-8")); os.flush(); os.close(); put.getResponseCode() postUi(function() prog.dismiss(); vibrarLarga(); hablar("Aviso enviado, vibración larga para usuarios"); Toast.makeText(ctxSafe(),"Aviso enviado",Toast.LENGTH_LONG).show(); mostrarNotificaciones() end) end) if not ok then postUi(function() prog.dismiss(); mostrarErrorDetallado("ERROR AVISO", tostring(err)) end) end end).start() end
function eliminarNotificacionGitHub(idNotif)
  local prog=mostrarProgreso("Eliminando aviso...")
  Thread(function()
    local ok,err=pcall(function()
      local api="https://api.github.com/repos/"..REPO.."/contents/notificaciones.json"
      local c=URL(api).openConnection(); c.setRequestMethod("GET"); c.setRequestProperty("Authorization","token "..TOKEN)
      local sha=""; local lista={}
      if c.getResponseCode()==200 then
        local br=BufferedReader(InputStreamReader(c.getInputStream())); local s=""; local l=br.readLine() while l~=nil do s=s..l; l=br.readLine() end br.close()
        local obj=cjson.decode(s); sha=obj.sha or ""
        if obj.content and obj.content~="" then
          local dec=tostring(String(Base64.decode(obj.content,Base64.DEFAULT),"UTF-8")); local dl=cjson.decode(dec); if dl then lista=dl end
        end
      end
      local encontrada=nil
      for _,n in ipairs(lista) do if tostring(n.id)==tostring(idNotif) then encontrada=n; break end end
      if encontrada then
        if ROL=="admin" and (encontrada.autor_lower or ""):lower()~=MI_USUARIO:lower() then error("Solo puedes borrar tus propios avisos") end
        if ROL=="invitado" or ROL=="visitante" then error("Sin permiso") end
      end
      local nueva={} for _,n in ipairs(lista) do if tostring(n.id)~=tostring(idNotif) then table.insert(nueva,n) end end
      NOTIFICACIONES_CACHE=nueva
      local j=cjson.encode(nueva); local enc=Base64.encodeToString(String(j).getBytes("UTF-8"),Base64.NO_WRAP)
      local put=URL(api).openConnection(); put.setRequestMethod("PUT"); put.setRequestProperty("Authorization","token "..TOKEN); put.setRequestProperty("Content-Type","application/json"); put.setDoOutput(true)
      local body={message="Eliminar aviso "..idNotif, content=enc, branch="main"}; if sha~="" then body.sha=sha end
      local os=put.getOutputStream(); os.write(String(cjson.encode(body)).getBytes("UTF-8")); os.flush(); os.close(); put.getResponseCode()
      postUi(function() prog.dismiss(); Toast.makeText(ctxSafe(),"Aviso eliminado",Toast.LENGTH_SHORT).show(); mostrarNotificaciones() end)
    end)
    if not ok then postUi(function() prog.dismiss(); mostrarErrorDetallado("ERROR ELIMINAR AVISO", tostring(err)) end) end
  end).start()
end
function abrirDialogoEnviarAviso() if ROL~="superadmin" and ROL~="admin" then Toast.makeText(ctxSafe(),"Sin permiso",Toast.LENGTH_SHORT).show(); return end local lay=LinearLayout(ctxSafe()); lay.setOrientation(LinearLayout.VERTICAL); lay.setPadding(20,20,20,20) local tv=TextView(ctxSafe()); tv.setText("Enviar Aviso"); tv.setTextColor(Color.WHITE); tv.setTextSize(16); lay.addView(tv) local edTitulo=EditText(ctxSafe()); edTitulo.setHint("Titulo del aviso"); lay.addView(edTitulo) local edMsg=EditText(ctxSafe()); edMsg.setHint("Mensaje"); edMsg.setMinLines(3); lay.addView(edMsg) local fila=LinearLayout(ctxSafe()); fila.setOrientation(LinearLayout.HORIZONTAL) local bC=Button(ctxSafe()); bC.setText("CANCELAR"); bC.setLayoutParams(LinearLayout.LayoutParams(0,-2,1)) local bE=Button(ctxSafe()); bE.setText("ENVIAR"); bE.setLayoutParams(LinearLayout.LayoutParams(0,-2,1)) fila.addView(bC); fila.addView(bE); lay.addView(fila) local d=LuaDialog(ctxSafe()); d.setView(lay); d.show() local lC={}; function lC.onClick(v) d.dismiss() end; bC.setOnClickListener(View.OnClickListener(lC)) local lE={}; function lE.onClick(v) d.dismiss(); enviarNotificacionGitHub(tostring(edTitulo.getText()), tostring(edMsg.getText())) end; bE.setOnClickListener(View.OnClickListener(lE)) end
function mostrarNotificaciones()
  if not listLayout then return end
  vibrar(); listLayout.removeAllViews()
  local noLeidasAntes,_=obtenerNoLeidas() if noLeidasAntes>0 then marcarTodasLeidas() hablar("Notificaciones, tienes 0 notificaciones sin leer") end
  local btnBack=Button(ctxSafe()); btnBack.setText("<- VOLVER"); local lBack={}; function lBack.onClick(v) vibrar(); mostrarPerfiles() end; btnBack.setOnClickListener(View.OnClickListener(lBack)); listLayout.addView(btnBack)
  if ROL=="superadmin" or ROL=="admin" then
    local btnEnviar=Button(ctxSafe()); btnEnviar.setText("ENVIAR NUEVO AVISO"); btnEnviar.setBackgroundColor(Color.parseColor("#FF1DB954")); btnEnviar.setTextColor(Color.WHITE)
    local lEnviar={}; function lEnviar.onClick(v) vibrar(); abrirDialogoEnviarAviso() end; btnEnviar.setOnClickListener(View.OnClickListener(lEnviar)); listLayout.addView(btnEnviar)
  end
  local tvEstado=TextView(ctxSafe()) tvEstado.setText("Notificaciones, tienes 0 notificaciones sin leer") tvEstado.setTextColor(Color.parseColor("#FF1DB954")) tvEstado.setTextSize(14) tvEstado.setGravity(Gravity.CENTER) tvEstado.setPadding(0,10,0,10) listLayout.addView(tvEstado)
  local tv=TextView(ctxSafe()); tv.setText("AVISOS ("..#NOTIFICACIONES_CACHE..")"); tv.setTextColor(Color.WHITE); tv.setTextSize(16); tv.setGravity(Gravity.CENTER); tv.setPadding(0,10,0,10); listLayout.addView(tv)
  if #NOTIFICACIONES_CACHE==0 then local tvV=TextView(ctxSafe()); tvV.setText("No hay avisos"); tvV.setTextColor(Color.GRAY); tvV.setGravity(Gravity.CENTER); listLayout.addView(tvV) return end
  for _,notif in ipairs(NOTIFICACIONES_CACHE) do
    local card=LinearLayout(ctxSafe()); card.setOrientation(LinearLayout.VERTICAL); card.setPadding(15,15,15,15); card.setBackgroundColor(Color.parseColor("#FF1E1E1E")); local lp=LinearLayout.LayoutParams(-1,-2); lp.setMargins(0,8,0,8); card.setLayoutParams(lp)
    local tvT=TextView(ctxSafe()); tvT.setText(notif.titulo or "Aviso"); tvT.setTextColor(Color.WHITE); tvT.setTextSize(14); card.addView(tvT)
    local tvM=TextView(ctxSafe()); tvM.setText(notif.mensaje or ""); tvM.setTextColor(Color.parseColor("#FFCCCCCC")); tvM.setTextSize(12); card.addView(tvM)
    local tvA=TextView(ctxSafe()); tvA.setText("De: "..(notif.autor or "Admin").." - "..os.date("%d/%m %H:%M", notif.fecha or os.time())); tvA.setTextColor(Color.GRAY); tvA.setTextSize(10); card.addView(tvA)
    local puedeBorrar=false
    if ROL=="superadmin" then puedeBorrar=true elseif ROL=="admin" and (notif.autor_lower or ""):lower()==MI_USUARIO:lower() then puedeBorrar=true end
    if puedeBorrar then
      local btnDel=Button(ctxSafe()); btnDel.setText("ELIMINAR AVISO"); btnDel.setBackgroundColor(Color.parseColor("#FFFF0000")); btnDel.setTextColor(Color.WHITE)
      local idN=notif.id local lDel={}; function lDel.onClick(v) vibrar(); eliminarNotificacionGitHub(idN) end; btnDel.setOnClickListener(View.OnClickListener(lDel)); card.addView(btnDel)
    end
    local lCard={}; function lCard.onClick(v) vibrar(); hablar((notif.titulo or "").." "..(notif.mensaje or "")) end; card.setOnClickListener(View.OnClickListener(lCard))
    listLayout.addView(card)
  end
end
-- ============ ACTUALIZACION AUTOMATICA DE LA TIENDA (SOLO TIENDA) ============
local UPDATE_MANIFEST_URL = "https://raw.githubusercontent.com/isaitduran8-star/App-Store-Company-/main/update.json"
local RAW_MAIN_LUA = "https://raw.githubusercontent.com/isaitduran8-star/App-Store-Company-/main/main.lua"
local MARCADOR_TIENDA = "App Store Company"
local CARPETA_PLUGINS = "/storage/emulated/0/解说/Plugins/"

function versionInstaladaTienda() return obtenerPrefs().getString("tienda_version", "1.3") end
function guardarVersionTienda(v) local ed=obtenerPrefs().edit() ed.putString("tienda_version", tostring(v)) ed.apply() end

function versionRemotaEsMayor(remota, localV)
  local a,b={},{}
  for n in tostring(remota):gmatch("%d+") do table.insert(a, tonumber(n)) end
  for n in tostring(localV):gmatch("%d+") do table.insert(b, tonumber(n)) end
  for i=1, math.max(#a,#b) do
    local x,y=a[i] or 0,b[i] or 0
    if x>y then return true elseif x<y then return false end
  end
  return false
end

-- Escanear la carpeta Plugins y encontrar el main.lua de LA TIENDA (no toca otros plugins)
function buscarArchivoTienda()
  local fijo=File(CARPETA_PLUGINS.."App store company/main.lua")
  if fijo.exists() then
    local okF,headF=pcall(function() local fis=FileInputStream(fijo) local buf=byte[4096] local n=fis.read(buf,0,4096) fis.close() if n and n>0 then return tostring(String(buf,0,n,"UTF-8")) end return "" end)
    if okF and headF and headF:find(MARCADOR_TIENDA,1,true) then return fijo.getAbsolutePath() end
  end
  local base=File(CARPETA_PLUGINS)
  if not base.exists() then return nil end
  local dirs=base.listFiles()
  if not dirs then return nil end
  for i=0,getLength(dirs)-1 do
    local d=dirs[i]
    if d.isDirectory() then
      local f=File(d.getAbsolutePath().."/main.lua")
      if f.exists() then
        local ok,head=pcall(function()
          local fis=FileInputStream(f)
          local buf=byte[4096]
          local n=fis.read(buf,0,4096)
          fis.close()
          if n and n>0 then return tostring(String(buf,0,n,"UTF-8")) end
          return ""
        end)
        if ok and head and head:find(MARCADOR_TIENDA,1,true) then return f.getAbsolutePath() end
      end
    end
  end
  return nil
end

-- Consultar update.json en GitHub
function consultarManifiestoActualizacion(cb)
  Thread(function()
    local info=nil
    pcall(function()
      local c=URL(UPDATE_MANIFEST_URL.."?t="..os.time()..math.random(1000,9999)).openConnection()
      c.setConnectTimeout(15000) c.setReadTimeout(15000)
      local br=BufferedReader(InputStreamReader(c.getInputStream()))
      local s="" local l=br.readLine() while l~=nil do s=s..l; l=br.readLine() end br.close()
      local m=cjson.decode(s)
      if m and m[1] and m[1].version and m[1].url then info=m[1] end
    end)
    postUi(function() if cb then cb(info) end end)
  end).start()
end

-- Descargar el codigo nuevo, sobrescribir el viejo en la carpeta del plugin y guardar la version
function descargarEInstalarActualizacion(info, cb)
  Thread(function()
    local ok,err=pcall(function()
      local c=URL(info.url).openConnection()
      c.setConnectTimeout(20000) c.setReadTimeout(20000)
      local br=BufferedReader(InputStreamReader(c.getInputStream()))
      local partes={} local l=br.readLine() while l~=nil do table.insert(partes,l); l=br.readLine() end br.close()
      local codigo=table.concat(partes,"\n")
      if #codigo<1000 or not codigo:find(MARCADOR_TIENDA,1,true) then error("El código descargado no es válido o está incompleto") end
      local ruta=buscarArchivoTienda()
      if not ruta then error("No se encontró la carpeta del plugin de la tienda en "..CARPETA_PLUGINS) end
      local fos=FileOutputStream(File(ruta))
      fos.write(String(codigo).getBytes("UTF-8"))
      fos.flush() fos.close()
      guardarVersionTienda(info.version)
    end)
    postUi(function() if cb then cb(ok,err) end end)
  end).start()
end

-- Actualizacion automatica al abrir la tienda (aplica al reabrir el complemento)
function autoActualizarTienda()
  consultarManifiestoActualizacion(function(info)
    if info and versionRemotaEsMayor(info.version, versionInstaladaTienda()) then
      descargarEInstalarActualizacion(info, function(ok)
        if ok then Toast.makeText(ctxSafe(),"Tienda actualizada a v"..info.version.." - se aplicará al reabrir",Toast.LENGTH_LONG).show() end
      end)
    end
  end)
end

-- Sube el main.lua actual de la tienda al repo y escribe la version en update.json
-- Sube el archivo seleccionado al repo y escribe la version en update.json
function subirActualizacionTiendaGitHub(rutaArchivo, versionNueva, fechaNueva, notasNueva, cb)
  local prog=mostrarProgreso("Subiendo actualización v"..tostring(versionNueva).."...")
  Thread(function()
    local ok,err=pcall(function()
      local ruta=rutaArchivo
      if not ruta then ruta=buscarArchivoTienda() end
      if not ruta then error("No se encontró la carpeta del plugin de la tienda en "..CARPETA_PLUGINS) end
      local f=File(ruta)
      local nombreSel=tostring(f.getName())
      local tam=tonumber(f.length())
      local arr=byte[tam]
      local fis=FileInputStream(f)
      local leido=0
      while leido<tam do local n=fis.read(arr, leido, tam-leido) if n==-1 then break end leido=leido+n end
      fis.close()
      local enc=Base64.encodeToString(arr, Base64.NO_WRAP)
      local function putConSha(api, encContent, mensaje)
        for intento=1,3 do
          local sha=""
          pcall(function()
            local g=URL(api).openConnection() g.setRequestMethod("GET") g.setRequestProperty("Authorization","token "..TOKEN)
            if g.getResponseCode()==200 then local br=BufferedReader(InputStreamReader(g.getInputStream())) local s="" local l=br.readLine() while l~=nil do s=s..l; l=br.readLine() end br.close() local obj=cjson.decode(s) if obj then sha=tostring(obj.sha or "") end end
          end)
          local p=URL(api).openConnection() p.setRequestMethod("PUT") p.setRequestProperty("Authorization","token "..TOKEN) p.setRequestProperty("Content-Type","application/json") p.setDoOutput(true)
          local body={message=mensaje, content=encContent, branch="main"}
          if sha~="" then body.sha=sha end
          local osp=p.getOutputStream() osp.write(String(cjson.encode(body)).getBytes("UTF-8")) osp.flush() osp.close()
          local code=p.getResponseCode()
          if code==200 or code==201 then return end
          local errBody=""
          pcall(function() local es=p.getErrorStream() if es then local br=BufferedReader(InputStreamReader(es)) local l=br.readLine() while l~=nil do errBody=errBody..l; l=br.readLine() end br.close() end end)
          if code==409 and intento<3 then
            -- conflicto: el archivo cambió en el servidor, se reintenta con sha fresco
          else
            error("FALLO AL SUBIR "..nombreSel.." código "..code.." "..errBody)
          end
        end
        error("FALLO AL SUBIR "..nombreSel.." código 409 persistente tras 3 intentos")
      end
      putConSha("https://api.github.com/repos/"..REPO.."/contents/"..nombreSel, enc, "Actualizar "..nombreSel.." v"..tostring(versionNueva))
      local manifesto={} manifesto[1]={version=tostring(versionNueva), fecha=tostring(fechaNueva), url="https://raw.githubusercontent.com/isaitduran8-star/App-Store-Company-/main/"..nombreSel, notas=tostring(notasNueva)}
      local jsonUpd=cjson.encode(manifesto)
      local encUpd=Base64.encodeToString(String(jsonUpd).getBytes("UTF-8"), Base64.NO_WRAP)
      putConSha("https://api.github.com/repos/"..REPO.."/contents/update.json", encUpd, "Versión tienda v"..tostring(versionNueva))
      guardarVersionTienda(versionNueva)
    end)
    postUi(function() prog.dismiss() if cb then cb(ok,err) end end)
  end).start()
end

function abrirDialogoSubirActualizacionTienda()
  local lay=LinearLayout(ctxSafe()) lay.setOrientation(LinearLayout.VERTICAL) lay.setPadding(20,20,20,20)
  local tv=TextView(ctxSafe()) tv.setText("Subir actualización de la tienda\nElige el archivo de la carpeta del plugin y pon la nueva versión") tv.setTextColor(Color.parseColor("#FF1DB954")) lay.addView(tv)
  local sel={} sel.path=nil sel.nombre=nil
  local lblSel=TextView(ctxSafe()) lblSel.setText("Archivo: ninguno - se subirá el main.lua actual de la tienda") lblSel.setTextColor(Color.GRAY) lay.addView(lblSel)
  local btnSel=Button(ctxSafe()) btnSel.setText("SELECCIONAR ARCHIVO") btnSel.setBackgroundColor(Color.parseColor("#FF2196F3")) btnSel.setTextColor(Color.WHITE) lay.addView(btnSel)
  local edVer=EditText(ctxSafe()) edVer.setHint("Versión nueva. Ej: 1.4") edVer.setTextColor(Color.WHITE) edVer.setHintTextColor(Color.GRAY) lay.addView(edVer)
  local edFecha=EditText(ctxSafe()) edFecha.setHint("Fecha. Ej: 26/09/2026") edFecha.setTextColor(Color.WHITE) edFecha.setHintTextColor(Color.GRAY)
  local d0=os.date("*t") edFecha.setText(string.format("%02d/%02d/%d", d0.day, d0.month, d0.year)) lay.addView(edFecha)
  local edNotas=EditText(ctxSafe()) edNotas.setHint("Notas de la versión") edNotas.setTextColor(Color.WHITE) edNotas.setHintTextColor(Color.GRAY) edNotas.setMinLines(3) lay.addView(edNotas)
  local fila=LinearLayout(ctxSafe()) fila.setOrientation(LinearLayout.HORIZONTAL)
  local bC=Button(ctxSafe()) bC.setText("CANCELAR") bC.setLayoutParams(LinearLayout.LayoutParams(0,-2,1))
  local bS=Button(ctxSafe()) bS.setText("SUBIR") bS.setBackgroundColor(Color.parseColor("#FF1DB954")) bS.setTextColor(Color.WHITE) bS.setLayoutParams(LinearLayout.LayoutParams(0,-2,1))
  fila.addView(bC) fila.addView(bS) lay.addView(fila)
  local d=LuaDialog(ctxSafe()) d.setView(lay) d.show()
  local lSel={} function lSel.onClick(v)
    vibrar()
    local layExp=LinearLayout(ctxSafe()) layExp.setOrientation(LinearLayout.VERTICAL) layExp.setPadding(10,10,10,10)
    local tvS=TextView(ctxSafe()) tvS.setText("Buscando archivos en la carpeta de la tienda...") layExp.addView(tvS)
    local lv=ListView(ctxSafe()) layExp.addView(lv)
    local dlgExp=LuaDialog(ctxSafe()) dlgExp.setView(layExp) dlgExp.setTitle("Seleccionar archivo") dlgExp.show()
    Thread(function()
      local lista={}
      local base=File(CARPETA_PLUGINS.."App store company/")
      if base.exists() then
        local files=base.listFiles()
        if files then
          for i=0,getLength(files)-1 do
            local f=files[i]
            if f.isFile() then local e={} e.nombre=f.getName() e.ruta=f.getAbsolutePath() table.insert(lista,e) end
          end
        end
      end
      postUi(function()
        if #lista==0 then tvS.setText("No se encontraron archivos en la carpeta") return end
        tvS.setText("Encontrados: "..#lista.." - toca uno para elegirlo")
        local noms=ArrayList()
        for k,v in ipairs(lista) do noms.add(v.nombre) end
        local adapter=ArrayAdapter(ctxSafe(), android.R.layout.simple_list_item_1, noms)
        lv.setAdapter(adapter)
        local lItem={} function lItem.onItemClick(p,vw,pos,id)
          local it=lista[pos+1]
          sel.path=it.ruta sel.nombre=it.nombre
          lblSel.setText("Archivo: "..it.nombre)
          dlgExp.dismiss()
        end
        lv.setOnItemClickListener(AdapterView.OnItemClickListener(lItem))
      end)
    end).start()
  end btnSel.setOnClickListener(View.OnClickListener(lSel))
  local lC={} function lC.onClick(v) d.dismiss() end bC.setOnClickListener(View.OnClickListener(lC))
  local lS={} function lS.onClick(v)
    local ver=tostring(edVer.getText()):gsub("^%s+",""):gsub("%s+$","")
    if ver=="" then Toast.makeText(ctxSafe(),"Pon el número de versión",Toast.LENGTH_SHORT).show() return end
    local fecha=tostring(edFecha.getText()):gsub("^%s+",""):gsub("%s+$","")
    if fecha=="" then fecha=os.date("%d/%m/%Y") end
    local notas=tostring(edNotas.getText())
    d.dismiss()
    subirActualizacionTiendaGitHub(sel.path, ver, fecha, notas, function(ok, err)
      if ok then
        reproducirSonido("éxito.mp3")
        Toast.makeText(ctxSafe(),"Actualización v"..ver.." publicada. Los usuarios se actualizarán al reabrir la tienda.",Toast.LENGTH_LONG).show()
      else
        mostrarErrorDetallado("ERROR AL PUBLICAR ACTUALIZACIÓN", tostring(err))
      end
    end)
  end bS.setOnClickListener(View.OnClickListener(lS))
end

function mostrarConfiguracion() if not listLayout then return end vibrar(); listLayout.removeAllViews() local prefs=obtenerPrefs() local vibraAct=prefs.getBoolean("cfg_vibra",true); local inten=prefs.getInt("cfg_inten",50) local confirmarAct=prefs.getBoolean("cfg_confirmar",true) local tvTitle=TextView(ctxSafe()); tvTitle.setText("CONFIGURACIÓN"); tvTitle.setTextColor(Color.WHITE); tvTitle.setTextSize(18); tvTitle.setGravity(Gravity.CENTER); listLayout.addView(tvTitle) local tvSon=TextView(ctxSafe()); tvSon.setText("EFECTOS DE SONIDO"); tvSon.setTextColor(Color.parseColor("#FF1DB954")); tvSon.setTextSize(15); tvSon.setPadding(0,20,0,5); listLayout.addView(tvSon) local txtEstadoSon=TextView(ctxSafe()); txtEstadoSon.setTextSize(12); txtEstadoSon.setTextColor(Color.GRAY); txtEstadoSon.setPadding(0,0,0,10); listLayout.addView(txtEstadoSon) local btnDescargarSonidos=Button(ctxSafe()); btnDescargarSonidos.setText("Descargar sonidos"); listLayout.addView(btnDescargarSonidos) local btnEliminarSonidos=Button(ctxSafe()); btnEliminarSonidos.setText("Eliminar efectos de sonido"); listLayout.addView(btnEliminarSonidos) local function refrescarBotonesSonidos() if existeCarpetaYSonidos() then txtEstadoSon.setText("Estado: Sonidos instalados en\n"..CARPETA_SONIDOS) btnDescargarSonidos.setEnabled(false); btnDescargarSonidos.setAlpha(0.4) btnEliminarSonidos.setEnabled(true); btnEliminarSonidos.setAlpha(1.0) else txtEstadoSon.setText("Estado: Sonidos no instalados - El complemento funciona sin sonidos") btnDescargarSonidos.setEnabled(true); btnDescargarSonidos.setAlpha(1.0) btnEliminarSonidos.setEnabled(false); btnEliminarSonidos.setAlpha(0.4) end end local lDescSon={}; function lDescSon.onClick(v) vibrar(); descargarYExtraerSonidos(refrescarBotonesSonidos) end; btnDescargarSonidos.setOnClickListener(View.OnClickListener(lDescSon)) local lElimSon={}; function lElimSon.onClick(v) vibrar() local lay=LinearLayout(ctxSafe()); lay.setPadding(20,20,20,20) local tv=TextView(ctxSafe()); tv.setText("¿Eliminar los sonidos del teléfono?\n"..CARPETA_SONIDOS); tv.setTextColor(Color.WHITE); lay.addView(tv) local fila=LinearLayout(ctxSafe()); fila.setOrientation(LinearLayout.HORIZONTAL) local bC=Button(ctxSafe()); bC.setText("Cancelar"); bC.setLayoutParams(LinearLayout.LayoutParams(0,-2,1)) local bE=Button(ctxSafe()); bE.setText("Eliminar"); bE.setLayoutParams(LinearLayout.LayoutParams(0,-2,1)) fila.addView(bC); fila.addView(bE); lay.addView(fila) local d=LuaDialog(ctxSafe()); d.setView(lay); d.show() local lC={}; function lC.onClick(v) d.dismiss() end; bC.setOnClickListener(View.OnClickListener(lC)) local lE={}; function lE.onClick(v) d.dismiss(); Thread(function() for _,n in ipairs(LISTA_SONIDOS) do pcall(function() File(CARPETA_SONIDOS..n).delete() end) end postUi(function() Toast.makeText(ctxSafe(),"Efectos de sonido eliminados",0).show(); refrescarBotonesSonidos() end) end).start() end; bE.setOnClickListener(View.OnClickListener(lE)) end; btnEliminarSonidos.setOnClickListener(View.OnClickListener(lElimSon)) refrescarBotonesSonidos() local layVib=LinearLayout(ctxSafe()); layVib.setOrientation(LinearLayout.HORIZONTAL); layVib.setPadding(10,10,10,10) local tvV=TextView(ctxSafe()); tvV.setText("Vibración: "); tvV.setTextColor(Color.WHITE); tvV.setLayoutParams(LinearLayout.LayoutParams(0,-2,1)); layVib.addView(tvV) local sw=Switch(ctxSafe()); sw.setChecked(vibraAct); layVib.addView(sw); listLayout.addView(layVib) local tvI=TextView(ctxSafe()); tvI.setText("Intensidad: "..inten); tvI.setTextColor(Color.GRAY); listLayout.addView(tvI) local seek=SeekBar(ctxSafe()); seek.setMax(100); seek.setProgress(inten); listLayout.addView(seek) local lSeek={} function lSeek.onProgressChanged(sb,prog,fromUser) tvI.setText("Intensidad: "..prog) end function lSeek.onStartTrackingTouch(sb) end function lSeek.onStopTrackingTouch(sb) vibrar() end seek.setOnSeekBarChangeListener(SeekBar.OnSeekBarChangeListener(lSeek)) local layConf=LinearLayout(ctxSafe()); layConf.setOrientation(LinearLayout.HORIZONTAL); layConf.setPadding(10,10,10,10) local tvC=TextView(ctxSafe()); tvC.setText("Pedir confirmación al instalar: "); tvC.setTextColor(Color.WHITE); tvC.setLayoutParams(LinearLayout.LayoutParams(0,-2,1)); layConf.addView(tvC) local swConf=Switch(ctxSafe()); swConf.setChecked(confirmarAct); layConf.addView(swConf); listLayout.addView(layConf) local btnGuardar=Button(ctxSafe()); btnGuardar.setText("GUARDAR CAMBIOS"); btnGuardar.setBackgroundColor(Color.parseColor("#FF1DB954")); btnGuardar.setTextColor(Color.WHITE) local lGuardar={} function lGuardar.onClick(v) vibrar() local ed=prefs.edit() ed.putBoolean("cfg_vibra", sw.isChecked()) ed.putInt("cfg_inten", seek.getProgress()) ed.putBoolean("cfg_confirmar", swConf.isChecked()) ed.apply() Toast.makeText(ctxSafe(),"Guardado",Toast.LENGTH_SHORT).show() mostrarPerfiles() end btnGuardar.setOnClickListener(View.OnClickListener(lGuardar)); listLayout.addView(btnGuardar) local btnCreditos=Button(ctxSafe()); btnCreditos.setText("CRÉDITOS"); btnCreditos.setBackgroundColor(Color.parseColor("#FF2196F3")); btnCreditos.setTextColor(Color.WHITE) local lCred={}; function lCred.onClick(v) vibrar(); mostrarDialogoCreditos(true) end; btnCreditos.setOnClickListener(View.OnClickListener(lCred)); listLayout.addView(btnCreditos) if ROL=="superadmin" then local btnAddAdmin=Button(ctxSafe()); btnAddAdmin.setText("AGREGAR ADMINISTRADOR"); btnAddAdmin.setBackgroundColor(Color.parseColor("#FF2196F3")); btnAddAdmin.setTextColor(Color.WHITE) local lAdd={}; function lAdd.onClick(v) vibrar(); abrirDialogoAgregarAdmin() end; btnAddAdmin.setOnClickListener(View.OnClickListener(lAdd)); listLayout.addView(btnAddAdmin) local btnListarAdmins=Button(ctxSafe()); btnListarAdmins.setText("LISTA DE ADMINISTRADORES / DESCARTAR"); btnListarAdmins.setBackgroundColor(Color.parseColor("#FFFF9800")); btnListarAdmins.setTextColor(Color.WHITE) local lList={}; function lList.onClick(v) vibrar(); mostrarListaAdminsParaDescartar() end; btnListarAdmins.setOnClickListener(View.OnClickListener(lList)); listLayout.addView(btnListarAdmins) end if ROL=="superadmin" then
  local btnAct=Button(ctxSafe()); btnAct.setText("BUSCAR ACTUALIZACIÓN DE LA TIENDA"); btnAct.setBackgroundColor(Color.parseColor("#FF9C27B0")); btnAct.setTextColor(Color.WHITE)
  local lAct={}
  function lAct.onClick(v)
    vibrar()
    consultarManifiestoActualizacion(function(info)
      if not info then Toast.makeText(ctxSafe(),"No se pudo consultar el servidor",Toast.LENGTH_LONG).show(); return end
      local localV=versionInstaladaTienda()
      if versionRemotaEsMayor(info.version, localV) then
        local lay=LinearLayout(ctxSafe()); lay.setOrientation(LinearLayout.VERTICAL); lay.setPadding(20,20,20,20)
        local tv=TextView(ctxSafe()); tv.setText("Nueva versión: v"..info.version.."\nActual: v"..localV.."\nFecha: "..(info.fecha or "?").."\n\n"..(info.notas or "")); tv.setTextColor(Color.WHITE); lay.addView(tv)
        local fila=LinearLayout(ctxSafe()); fila.setOrientation(LinearLayout.HORIZONTAL)
        local bC=Button(ctxSafe()); bC.setText("CANCELAR"); bC.setLayoutParams(LinearLayout.LayoutParams(0,-2,1))
        local bA=Button(ctxSafe()); bA.setText("ACTUALIZAR"); bA.setLayoutParams(LinearLayout.LayoutParams(0,-2,1))
        fila.addView(bC); fila.addView(bA); lay.addView(fila)
        local d=LuaDialog(ctxSafe()); d.setView(lay); d.setCancelable(false); d.show()
        local lC={}; function lC.onClick(v) d.dismiss() end; bC.setOnClickListener(View.OnClickListener(lC))
        local lA={}; function lA.onClick(v)
          d.dismiss()
          local prog=mostrarProgreso("Actualizando tienda...")
          descargarEInstalarActualizacion(info, function(ok2, err2)
            prog.dismiss()
            if ok2 then
              reproducirSonido("éxito.mp3")
              local lay2=LinearLayout(ctxSafe()); lay2.setPadding(20,20,20,20)
              local tv2=TextView(ctxSafe()); tv2.setText("Actualización instalada (v"..info.version..").\nLa nueva versión se abrirá al volver a entrar al complemento."); tv2.setTextColor(Color.WHITE); lay2.addView(tv2)
              local b2=Button(ctxSafe()); b2.setText("Entendido"); lay2.addView(b2)
              local d2=LuaDialog(ctxSafe()); d2.setView(lay2); d2.setCancelable(false); d2.show()
              local l2={}; function l2.onClick(v) d2.dismiss() end; b2.setOnClickListener(View.OnClickListener(l2))
            else
              mostrarErrorDetallado("ERROR AL ACTUALIZAR", tostring(err2))
            end
          end)
        end; bA.setOnClickListener(View.OnClickListener(lA))
      else
        Toast.makeText(ctxSafe(),"La tienda está actualizada (instalada v"..localV.." - servidor v"..info.version..")",Toast.LENGTH_LONG).show()
      end
    end)
  end
  btnAct.setOnClickListener(View.OnClickListener(lAct)); listLayout.addView(btnAct)
  local btnPub=Button(ctxSafe()); btnPub.setText("SUBIR ACTUALIZACIÓN DE LA TIENDA"); btnPub.setBackgroundColor(Color.parseColor("#FF673AB7")); btnPub.setTextColor(Color.WHITE)
  local lPub={}; function lPub.onClick(v) vibrar(); abrirDialogoSubirActualizacionTienda() end; btnPub.setOnClickListener(View.OnClickListener(lPub)); listLayout.addView(btnPub)
end
local btnCerrarSes=Button(ctxSafe()); btnCerrarSes.setText("CERRAR SESIÓN"); btnCerrarSes.setBackgroundColor(Color.parseColor("#FFFF5722")); btnCerrarSes.setTextColor(Color.WHITE) local lCerrarSes={} function lCerrarSes.onClick(v) vibrar() local prefs=obtenerPrefs() local ed=prefs.edit() ed.putBoolean("guardar_sesion",false) ed.remove("usuario_guardado") ed.remove("rol_guardado") ed.remove("nombre_guardado") ed.apply() YA_RECUPERADO=false ARCHIVOS_CACHE={} PERFILES_CACHE={} if mainDialog then mainDialog.dismiss() end mainDialog=nil listLayout=nil mostrarLogin() end btnCerrarSes.setOnClickListener(View.OnClickListener(lCerrarSes)); listLayout.addView(btnCerrarSes) local btnVolver=Button(ctxSafe()); btnVolver.setText("VOLVER"); btnVolver.setBackgroundColor(Color.parseColor("#FF222222")); btnVolver.setTextColor(Color.WHITE) local lVolver={} function lVolver.onClick(v) vibrar(); mostrarPerfiles() end btnVolver.setOnClickListener(View.OnClickListener(lVolver)); listLayout.addView(btnVolver) end
function abrirDialogoAgregarAdmin() local lay=LinearLayout(ctxSafe()); lay.setOrientation(LinearLayout.VERTICAL); lay.setPadding(20,20,20,20) local tv=TextView(ctxSafe()); tv.setText("Agregar Administrador"); tv.setTextColor(Color.WHITE); lay.addView(tv) local edUsuario=EditText(ctxSafe()); edUsuario.setHint("Usuario interno Jieshuo"); lay.addView(edUsuario) local edNombre=EditText(ctxSafe()); edNombre.setHint("Nombre público"); lay.addView(edNombre) local fila=LinearLayout(ctxSafe()); fila.setOrientation(LinearLayout.HORIZONTAL) local bC=Button(ctxSafe()); bC.setText("CANCELAR"); bC.setLayoutParams(LinearLayout.LayoutParams(0,-2,1)) local bA=Button(ctxSafe()); bA.setText("AGREGAR"); bA.setLayoutParams(LinearLayout.LayoutParams(0,-2,1)) fila.addView(bC); fila.addView(bA); lay.addView(fila) local d=LuaDialog(ctxSafe()); d.setView(lay); d.show() local lC={}; function lC.onClick(v) d.dismiss() end; bC.setOnClickListener(View.OnClickListener(lC)) local lA={}; function lA.onClick(v) local u=tostring(edUsuario.getText()):gsub("%s+","") local n=tostring(edNombre.getText()) if u=="" or n=="" then Toast.makeText(ctxSafe(),"Llena ambos campos",Toast.LENGTH_SHORT).show(); return end d.dismiss(); agregarAdministradorGitHub("admin", u, n, nil) end; bA.setOnClickListener(View.OnClickListener(lA)) end
function mostrarListaAdminsParaDescartar() if not listLayout then return end vibrar(); listLayout.removeAllViews() local btnBack=Button(ctxSafe()); btnBack.setText("<- VOLVER"); local lBack={}; function lBack.onClick(v) vibrar(); mostrarConfiguracion() end; btnBack.setOnClickListener(View.OnClickListener(lBack)); listLayout.addView(btnBack) local tv=TextView(ctxSafe()); tv.setText("ADMINISTRADORES"); tv.setTextColor(Color.WHITE); tv.setTextSize(14); tv.setGravity(Gravity.CENTER); tv.setPadding(0,10,0,10); listLayout.addView(tv) local hay=false for _,p in ipairs(PERFILES_CACHE) do if p.usuario:lower()~="aplicaciones company" then local esDescartado=false for _,u in ipairs(DESCARTADOS_CACHE) do if u:lower()==p.usuario:lower() then esDescartado=true; break end end if not esDescartado then hay=true local card=LinearLayout(ctxSafe()); card.setOrientation(LinearLayout.HORIZONTAL); card.setPadding(10,10,10,10); card.setBackgroundColor(Color.parseColor("#FF1E1E1E")); local lp=LinearLayout.LayoutParams(-1,-2); lp.setMargins(0,5,0,5); card.setLayoutParams(lp) local tvN=TextView(ctxSafe()); tvN.setText(p.nombre); tvN.setTextColor(Color.WHITE); tvN.setLayoutParams(LinearLayout.LayoutParams(0,-2,1)); card.addView(tvN) local btnDesc=Button(ctxSafe()); btnDesc.setText("DESCARTAR"); btnDesc.setBackgroundColor(Color.RED); btnDesc.setTextColor(Color.WHITE) local usuario=p.usuario local lDesc={}; function lDesc.onClick(v) vibrar(); descartarUsuarioGitHub(usuario, nil) end; btnDesc.setOnClickListener(View.OnClickListener(lDesc)); card.addView(btnDesc) listLayout.addView(card) end end end if not hay then local tvV=TextView(ctxSafe()); tvV.setText("No hay administradores"); tvV.setTextColor(Color.GRAY); tvV.setGravity(Gravity.CENTER); listLayout.addView(tvV) end end
function mostrarInterfaz()
  local mainLay=LinearLayout(ctxSafe()); mainLay.setOrientation(LinearLayout.VERTICAL); mainLay.setPadding(20,20,20,20); mainLay.setBackgroundColor(Color.parseColor("#FF121212"))
  local scroll=ScrollView(ctxSafe()); listLayout=LinearLayout(ctxSafe()); listLayout.setOrientation(LinearLayout.VERTICAL); scroll.addView(listLayout); mainLay.addView(scroll)
  mainDialog=LuaDialog(ctxSafe())
  mainDialog.setTitle("")
  mainDialog.setView(mainLay)
  mainDialog.setCancelable(false)
  mainDialog.show()
  mostrarPerfiles()
  verificarCreditosUnicaVez()
  verificarSonidosAlIniciar()
  autoActualizarTienda()
end
function mostrarPerfiles()
  if not listLayout then return end
  vibrar(); listLayout.removeAllViews()
  -- TITULOS SOLO EN PANTALLA PRINCIPAL - desaparecen al entrar a apartados
  local tvTienda=TextView(ctxSafe()); tvTienda.setText("App Store Company"); tvTienda.setTextColor(Color.WHITE); tvTienda.setTextSize(20); tvTienda.setGravity(Gravity.CENTER); tvTienda.setPadding(0,0,0,10); listLayout.addView(tvTienda)
  local tvSel=TextView(ctxSafe()); tvSel.setText("selecciona un usuario"); tvSel.setTextColor(Color.parseColor("#FF1DB954")); tvSel.setTextSize(16); tvSel.setGravity(Gravity.CENTER); tvSel.setPadding(0,0,0,20); listLayout.addView(tvSel)

  if not perfilActual or perfilActual=="" then perfilActual=MI_NOMBRE_PUBLICO~="" and MI_NOMBRE_PUBLICO or "Aplicaciones Company" end
  for _,p in ipairs(PERFILES_CACHE) do
    local esDescartado=false
    for _,u in ipairs(DESCARTADOS_CACHE) do if u:lower()==p.usuario:lower() then esDescartado=true; break end end
    if not esDescartado then
      local btn=Button(ctxSafe()); btn.setText(p.nombre)
      if p.usuario=="aplicaciones company" then btn.setText("Aplicaciones Company") btn.setBackgroundColor(Color.parseColor("#FF1DB954")) else btn.setBackgroundColor(Color.parseColor("#FF1E1E1E")) end
      btn.setTextColor(Color.WHITE); local lp=LinearLayout.LayoutParams(-1,-2); lp.setMargins(0,8,0,8); btn.setLayoutParams(lp)
      local perfil=p
      local l={}; function l.onClick(v) vibrar(); perfilActual=perfil.nombre; BUSQUEDA_ACTUAL=""; ORDEN_ACTUAL="reciente"; mostrarCategorias() end; btn.setOnClickListener(View.OnClickListener(l)); listLayout.addView(btn)
    end
  end
  local noLeidas,_=obtenerNoLeidas() local textoNoti="Notificaciones, tienes "..noLeidas.." notificaciones nuevas" if noLeidas==0 then textoNoti="Notificaciones, tienes 0 notificaciones sin leer" end
  local btnNotifs=Button(ctxSafe()); btnNotifs.setText("🔔 "..textoNoti.." ("..#NOTIFICACIONES_CACHE..")"); btnNotifs.setBackgroundColor(Color.parseColor("#FFFF9800")); btnNotifs.setTextColor(Color.WHITE); local lpN=LinearLayout.LayoutParams(-1,-2); lpN.setMargins(0,10,0,10); btnNotifs.setLayoutParams(lpN); local lNot={}; function lNot.onClick(v) vibrar(); mostrarNotificaciones() end; btnNotifs.setOnClickListener(View.OnClickListener(lNot)); listLayout.addView(btnNotifs)
  local btnCfg=Button(ctxSafe()); btnCfg.setText("⚙ CONFIGURACIÓN"); btnCfg.setBackgroundColor(Color.parseColor("#FF333333")); btnCfg.setTextColor(Color.WHITE); local lp2=LinearLayout.LayoutParams(-1,-2); lp2.setMargins(0,15,0,15); btnCfg.setLayoutParams(lp2) local lCfg={}; function lCfg.onClick(v) vibrar(); mostrarConfiguracion() end; btnCfg.setOnClickListener(View.OnClickListener(lCfg)); listLayout.addView(btnCfg)
  local btnCerrar=Button(ctxSafe()); btnCerrar.setText("CERRAR"); btnCerrar.setBackgroundColor(Color.RED); btnCerrar.setTextColor(Color.WHITE) local lCerrar={}; function lCerrar.onClick(v) vibrar(); mostrarDialogoSalir() end; btnCerrar.setOnClickListener(View.OnClickListener(lCerrar)); listLayout.addView(btnCerrar)
end
function mostrarCategorias()
  if not listLayout then return end
  vibrar(); listLayout.removeAllViews()
  if not perfilActual or perfilActual=="" then perfilActual=MI_NOMBRE_PUBLICO~="" and MI_NOMBRE_PUBLICO or "Aplicaciones Company" end
  if not categoriaActual or categoriaActual=="" then categoriaActual="Complementos" end
  local btnBack=Button(ctxSafe()); btnBack.setText("<- VOLVER"); local lBack={}; function lBack.onClick(v) vibrar(); BUSQUEDA_ACTUAL=""; mostrarPerfiles() end; btnBack.setOnClickListener(View.OnClickListener(lBack)); listLayout.addView(btnBack)
  local tvP=TextView(ctxSafe()); tvP.setText(tostring(perfilActual)); tvP.setTextColor(Color.WHITE); tvP.setTextSize(18); tvP.setGravity(Gravity.CENTER); listLayout.addView(tvP)
  local conteo={}; conteo["Complementos"]=0; conteo["Temas de Sonido"]=0; conteo["Herramientas"]=0
  for k,it in ipairs(ARCHIVOS_CACHE) do if debeMostrarArchivoEnPerfil(it, perfilActual) then if conteo[it.categoria]~=nil then conteo[it.categoria]=conteo[it.categoria]+1 else conteo[it.categoria]=1 end end end
  local cats={"Complementos","Temas de Sonido","Herramientas"}
  for k,cat in ipairs(cats) do
    local btn=Button(ctxSafe()); btn.setText(cat.." ("..(conteo[cat] or 0)..")"); btn.setBackgroundColor(Color.parseColor("#FF1E1E1E")); btn.setTextColor(Color.WHITE); local lp=LinearLayout.LayoutParams(-1,-2); lp.setMargins(0,10,0,10); btn.setLayoutParams(lp); if (conteo[cat] or 0)>0 then btn.setBackgroundColor(Color.parseColor("#FF1DB954")) end
    local l={}; function l.onClick(v) vibrar(); categoriaActual=cat; BUSQUEDA_ACTUAL=""; ORDEN_ACTUAL="reciente"; mostrarArchivos() end; btn.setOnClickListener(View.OnClickListener(l)); listLayout.addView(btn)
  end
end
function obtenerPromedio(nombre) local sum=0; local count=0; for k,cal in ipairs(CALIFICACIONES_CACHE) do if cal.nombre:lower()==nombre:lower() then sum=sum+(cal.estrellas or 0); count=count+1 end end; if count==0 then return 0,0 else return sum/count,count end end
function mostrarArchivos()
  if not listLayout then return end
  vibrar(); listLayout.removeAllViews()
  if not categoriaActual or categoriaActual=="" then categoriaActual="Complementos" end
  if not perfilActual or perfilActual=="" then perfilActual=MI_NOMBRE_PUBLICO~="" and MI_NOMBRE_PUBLICO or "Aplicaciones Company" end
  local btnBack=Button(ctxSafe()); btnBack.setText("<- VOLVER A CATEGORIAS"); local lBack={}; function lBack.onClick(v) vibrar(); BUSQUEDA_ACTUAL=""; mostrarCategorias() end; btnBack.setOnClickListener(View.OnClickListener(lBack)); listLayout.addView(btnBack)
  local puedeSubirAqui=false
  if ROL=="superadmin" then puedeSubirAqui=true elseif ROL=="admin" and perfilActual:lower()==MI_NOMBRE_PUBLICO:lower() then puedeSubirAqui=true end
  if ROL=="invitado" or ROL=="visitante" then puedeSubirAqui=false end
  if puedeSubirAqui then
    local textoBoton="SUBIR "..tostring(categoriaActual):upper().." A "..perfilActual:upper()
    if ROL=="superadmin" and perfilActual:lower()~=MI_NOMBRE_PUBLICO:lower() and perfilActual:lower()~="aplicaciones company" then textoBoton="SUBIR "..tostring(categoriaActual):upper().." PARA "..perfilActual:upper().." (como principal)" end
    local btnSub=Button(ctxSafe()); btnSub.setText(textoBoton); btnSub.setBackgroundColor(Color.parseColor("#FF1DB954")); btnSub.setTextColor(Color.WHITE); local lSub={}; function lSub.onClick(v) vibrar(); abrirDialogoSubida(categoriaActual,false,nil) end; btnSub.setOnClickListener(View.OnClickListener(lSub)); listLayout.addView(btnSub)
  end
  local layBusca=LinearLayout(ctxSafe()); layBusca.setOrientation(LinearLayout.HORIZONTAL); layBusca.setPadding(0,10,0,5)
  local edBuscar=EditText(ctxSafe())
  edBuscar.setHint("Buscar en "..categoriaActual)
  edBuscar.setText(BUSQUEDA_ACTUAL)
  edBuscar.setLayoutParams(LinearLayout.LayoutParams(0,-2,1))
  edBuscar.setTextColor(Color.WHITE)
  edBuscar.setHintTextColor(Color.GRAY)
  edBuscar.setInputType(InputType.TYPE_CLASS_TEXT)
  edBuscar.setFocusable(true)
  edBuscar.setFocusableInTouchMode(true)
  edBuscar.setSingleLine(true)
  local btnBuscar=Button(ctxSafe()); btnBuscar.setText("🔍 BUSCAR"); btnBuscar.setBackgroundColor(Color.parseColor("#FF2196F3")); btnBuscar.setTextColor(Color.WHITE)
  layBusca.addView(edBuscar); layBusca.addView(btnBuscar); listLayout.addView(layBusca)
  local layOrden=LinearLayout(ctxSafe()); layOrden.setOrientation(LinearLayout.HORIZONTAL); layOrden.setPadding(0,5,0,10)
  local tvOrden=TextView(ctxSafe()); tvOrden.setText("Orden: "..ORDEN_ACTUAL); tvOrden.setTextColor(Color.GRAY); tvOrden.setLayoutParams(LinearLayout.LayoutParams(0,-2,1))
  local btnOrden=Button(ctxSafe()); btnOrden.setText("↕ ORDENAR"); btnOrden.setBackgroundColor(Color.parseColor("#FF444444")); btnOrden.setTextColor(Color.WHITE)
  layOrden.addView(tvOrden); layOrden.addView(btnOrden); listLayout.addView(layOrden)
  local lClickBuscar={}; function lClickBuscar.onClick(v) vibrar(); BUSQUEDA_ACTUAL=tostring(edBuscar.getText()):lower():gsub("^%s+",""):gsub("%s+$",""); mostrarArchivos() end; btnBuscar.setOnClickListener(View.OnClickListener(lClickBuscar))
  local lEdit={}
  function lEdit.onClick(v) forzarTeclado(edBuscar) end
  edBuscar.setOnClickListener(View.OnClickListener(lEdit))
  local lOrden={}; function lOrden.onClick(v)
    vibrar()
    local lay=LinearLayout(ctxSafe()); lay.setOrientation(LinearLayout.VERTICAL); lay.setPadding(10,10,10,10)
    local ops={"reciente","antiguo","descargado","popular"}
    local lv=ListView(ctxSafe()); local ad=ArrayList(); ad.add("Más reciente"); ad.add("Más antiguo"); ad.add("Más descargado"); ad.add("Más popular"); lv.setAdapter(ArrayAdapter(ctxSafe(), android.R.layout.simple_list_item_1, ad))
    lay.addView(lv)
    local d=LuaDialog(ctxSafe()); d.setView(lay); d.setTitle("Ordenar por"); d.show()
    local li={}; function li.onItemClick(p,v,pos,id) ORDEN_ACTUAL=ops[pos+1]; d.dismiss(); mostrarArchivos() end; lv.setOnItemClickListener(AdapterView.OnItemClickListener(li))
  end; btnOrden.setOnClickListener(View.OnClickListener(lOrden))
  local lista={}
  for k,it in ipairs(ARCHIVOS_CACHE) do
    if it.categoria==categoriaActual and debeMostrarArchivoEnPerfil(it, perfilActual) then
      local pasaFiltro=true
      if BUSQUEDA_ACTUAL~="" then
        local txtBusq=(it.nombre.." "..(it.descripcion or "")):lower()
        if not txtBusq:find(BUSQUEDA_ACTUAL,1,true) then pasaFiltro=false end
      end
      if pasaFiltro then table.insert(lista,it) end
    end
  end
  if ORDEN_ACTUAL=="descargado" then
    table.sort(lista,function(a,b) return (a.descargas or 0) > (b.descargas or 0) end)
  elseif ORDEN_ACTUAL=="reciente" then
    table.sort(lista,function(a,b) return (a.fecha or 0) > (b.fecha or 0) end)
  elseif ORDEN_ACTUAL=="antiguo" then
    table.sort(lista,function(a,b) return (a.fecha or 0) < (b.fecha or 0) end)
  elseif ORDEN_ACTUAL=="popular" then
    table.sort(lista,function(a,b)
      local pa,ca=obtenerPromedio(a.nombre); local pb,cb=obtenerPromedio(b.nombre)
      local scoreA=pa*10 + (a.descargas or 0)/10; local scoreB=pb*10 + (b.descargas or 0)/10
      return scoreA > scoreB
    end)
  end
  if #lista==0 then
    local tv=TextView(ctxSafe()); tv.setText("No hay resultados en "..tostring(categoriaActual).." de "..perfilActual..(BUSQUEDA_ACTUAL~="" and " para '"..BUSQUEDA_ACTUAL.."'" or "")); tv.setTextColor(Color.GRAY); tv.setGravity(Gravity.CENTER); listLayout.addView(tv)
  end
  for k,arch in ipairs(lista) do
    local prom,cnt=obtenerPromedio(arch.nombre)
    local card=LinearLayout(ctxSafe()); card.setOrientation(LinearLayout.VERTICAL); card.setPadding(15,15,15,15); card.setBackgroundColor(Color.parseColor("#FF1E1E1E")); local lp=LinearLayout.LayoutParams(-1,-2); lp.setMargins(0,8,0,8); card.setLayoutParams(lp)
    local fechaTexto=fechaBonita(arch.fecha)
    local tvN=TextView(ctxSafe()); tvN.setText(nombreVisible(arch.nombre)); tvN.setTextColor(Color.WHITE); tvN.setTextSize(14)
    local tvAutor=TextView(ctxSafe()); tvAutor.setText("Autor: "..(arch.autor or "Aplicaciones Company")); tvAutor.setTextColor(Color.parseColor("#FF1DB954")); tvAutor.setTextSize(12)
    local tvD=TextView(ctxSafe()); tvD.setText(arch.descripcion or "Este es un plugin 1"); tvD.setTextColor(Color.GRAY); tvD.setTextSize(12)
    local tvStats=TextView(ctxSafe()); tvStats.setText("Descargas: "..(arch.descargas or 0).." | Calificaciones: "..cnt.." | "..string.format("%.1f ★",prom).."\nÚltima actualización: "..fechaTexto); tvStats.setTextColor(Color.parseColor("#FFFFC107")); tvStats.setTextSize(11)
    card.addView(tvN); card.addView(tvAutor); card.addView(tvD); card.addView(tvStats)
    local lCard={}; function lCard.onClick(v) vibrar(); mostrarOpciones(arch) end; card.setOnClickListener(View.OnClickListener(lCard)); listLayout.addView(card)
  end
end
function mostrarOpciones(arch)
  vibrar()
  local prom,cnt=obtenerPromedio(arch.nombre)
  local fechaLarga=fechaBonita(arch.fecha or os.time())
  local lay=LinearLayout(ctxSafe()); lay.setOrientation(LinearLayout.VERTICAL); lay.setPadding(20,20,20,20); lay.setBackgroundColor(Color.parseColor("#FF121212"))
  local textoPrincipal=nombreVisible(arch.nombre).."\nDescripción: "..(arch.descripcion or "Este es un plugin 1").."\nDescargas: "..(arch.descargas or 0).."\nCalificaciones: "..cnt.." ("..string.format("%.1f",prom).." ★)\nÚltima actualización: "..fechaLarga
  local tv=TextView(ctxSafe()); tv.setText(textoPrincipal); tv.setTextColor(Color.WHITE); tv.setTextSize(13); tv.setTextIsSelectable(true); lay.addView(tv)
  local d=LuaDialog(ctxSafe()); d.setView(lay); d.show()
  local textoVoz=nombreVisible(arch.nombre).." descripción "..(arch.descripcion or "sin descripción").." descargas "..(arch.descargas or 0).." calificaciones "..cnt.." última actualización "..fechaLarga hablar(textoVoz)
  local function addBtn(txt,col,cb) local b=Button(ctxSafe()); b.setText(txt); b.setBackgroundColor(Color.parseColor(col)); b.setTextColor(Color.WHITE); local l={}; function l.onClick(v) vibrar(); cb() end; b.setOnClickListener(View.OnClickListener(l)); lay.addView(b) end
  addBtn("INSTALAR","#FF1DB954",function() d.dismiss(); confirmarEInstalar(arch) end)
  addBtn("VER CALIFICACIONES","#FF2196F3",function() d.dismiss(); mostrarListaCalificaciones(arch) end)
  addBtn("CALIFICAR ★","#FFFFC107",function() d.dismiss(); abrirDialogoCalificar(arch) end)
  local puedeEditar=false if ROL=="superadmin" then puedeEditar=true elseif ROL=="admin" and (arch.autor_lower or ""):lower()==MI_USUARIO:lower() then puedeEditar=true end
  if puedeEditar then addBtn("EDITAR","#FF555555",function() d.dismiss(); abrirDialogoSubida(arch.categoria,true,arch.nombre) end) addBtn("ELIMINAR","#FFFF0000",function() d.dismiss(); eliminarComplementoGitHub(arch, function() mostrarCategorias() end) end) end
  addBtn("VOLVER","#FF222222",function() d.dismiss() end)
end
function confirmarEInstalar(arch)
  local prefs=obtenerPrefs() local debeConfirmar=prefs.getBoolean("cfg_confirmar",true) if not debeConfirmar then instalar(arch); return end
  local lay=LinearLayout(ctxSafe()); lay.setPadding(20,20,20,20)
  local tv=TextView(ctxSafe()); tv.setText("¿Deseas instalar este complemento?\n"..nombreVisible(arch.nombre)); tv.setTextColor(Color.WHITE); lay.addView(tv)
  local fila=LinearLayout(ctxSafe()); fila.setOrientation(LinearLayout.HORIZONTAL)
  local bNo=Button(ctxSafe()); bNo.setText("CANCELAR"); bNo.setLayoutParams(LinearLayout.LayoutParams(0,-2,1))
  local bSi=Button(ctxSafe()); bSi.setText("INSTALAR"); bSi.setLayoutParams(LinearLayout.LayoutParams(0,-2,1))
  fila.addView(bNo); fila.addView(bSi); lay.addView(fila)
  local d=LuaDialog(ctxSafe()); d.setView(lay); d.setTitle("Confirmar instalación"); d.setCancelable(false); d.show()
  local lNo={}; function lNo.onClick(v) d.dismiss() end; bNo.setOnClickListener(View.OnClickListener(lNo))
  local lSi={}; function lSi.onClick(v) d.dismiss(); vibrar(); instalar(arch) end; bSi.setOnClickListener(View.OnClickListener(lSi))
  hablar("¿Deseas instalar este complemento "..nombreVisible(arch.nombre).."?")
end
function mostrarListaCalificaciones(arch) local lay=LinearLayout(ctxSafe()); lay.setOrientation(LinearLayout.VERTICAL); lay.setPadding(20,20,20,20) local scroll=ScrollView(ctxSafe()); local inner=LinearLayout(ctxSafe()); inner.setOrientation(LinearLayout.VERTICAL); scroll.addView(inner); lay.addView(scroll) local hay=false for k,cal in ipairs(CALIFICACIONES_CACHE) do if cal.nombre:lower()==arch.nombre:lower() then hay=true; local card=LinearLayout(ctxSafe()); card.setOrientation(LinearLayout.VERTICAL); card.setPadding(10,10,10,10); card.setBackgroundColor(Color.parseColor("#FF1E1E1E")); local lp=LinearLayout.LayoutParams(-1,-2); lp.setMargins(0,5,0,5); card.setLayoutParams(lp); local t1=TextView(ctxSafe()); t1.setText(cal.usuario.." - "..cal.estrellas.." ★"); t1.setTextColor(Color.WHITE); card.addView(t1); if cal.comentario and cal.comentario~="" then local t2=TextView(ctxSafe()); t2.setText(cal.comentario); t2.setTextColor(Color.GRAY); card.addView(t2) end local puedeBorrarPropia=false if (cal.usuario_lower or ""):lower()==MI_USUARIO:lower() then puedeBorrarPropia=true end if puedeBorrarPropia or ROL=="superadmin" or ROL=="admin" then local btnDelR=Button(ctxSafe()); btnDelR.setText("ELIMINAR MI RESEÑA"); btnDelR.setBackgroundColor(Color.RED); btnDelR.setTextColor(Color.WHITE) local calNombre=cal.nombre; local calUserLower=cal.usuario_lower local lDelR={}; function lDelR.onClick(v) vibrar(); eliminarCalificacionPropia(calNombre, calUserLower) end; btnDelR.setOnClickListener(View.OnClickListener(lDelR)); card.addView(btnDelR) end inner.addView(card) end end if not hay then local tv=TextView(ctxSafe()); tv.setText("Sin calificaciones aún"); tv.setTextColor(Color.GRAY); inner.addView(tv) end local btn=Button(ctxSafe()); btn.setText("CERRAR"); inner.addView(btn) local d=LuaDialog(ctxSafe()); d.setView(lay); d.show() local l={}; function l.onClick(v) d.dismiss() end; btn.setOnClickListener(View.OnClickListener(l)) end
function eliminarCalificacionPropia(nombreArch, usuarioLower) if (usuarioLower or ""):lower()~=MI_USUARIO:lower() and ROL~="superadmin" and ROL~="admin" then Toast.makeText(ctxSafe(),"Solo puedes borrar tu reseña",Toast.LENGTH_SHORT).show(); return end local prog=mostrarProgreso("Eliminando reseña...") Thread(function() local ok,err=pcall(function() local api="https://api.github.com/repos/"..REPO.."/contents/calificaciones.json"; local c=URL(api).openConnection(); c.setRequestMethod("GET"); c.setRequestProperty("Authorization","token "..TOKEN); local sha=""; local lista={} if c.getResponseCode()==200 then local br=BufferedReader(InputStreamReader(c.getInputStream())); local s=""; local l=br.readLine() while l~=nil do s=s..l; l=br.readLine() end br.close(); local obj=cjson.decode(s); sha=obj.sha; if obj.content then local dec=tostring(String(Base64.decode(obj.content,Base64.DEFAULT),"UTF-8")); local dl=cjson.decode(dec); if dl then lista=dl end end end local nueva={} for _,cal in ipairs(lista) do if not (cal.nombre:lower()==nombreArch:lower() and (cal.usuario_lower or ""):lower()==(usuarioLower or ""):lower()) then table.insert(nueva,cal) end end CALIFICACIONES_CACHE=nueva local newJson=cjson.encode(nueva); local enc=Base64.encodeToString(String(newJson).getBytes("UTF-8"),Base64.NO_WRAP); local put=URL(api).openConnection(); put.setRequestMethod("PUT"); put.setRequestProperty("Authorization","token "..TOKEN); put.setRequestProperty("Content-Type","application/json"); put.setDoOutput(true) local body={message="Borrar reseña "..nombreArch, content=enc, branch="main", sha=sha}; local os=put.getOutputStream(); os.write(String(cjson.encode(body)).getBytes("UTF-8")); os.flush(); os.close() postUi(function() prog.dismiss(); Toast.makeText(ctxSafe(),"Reseña eliminada",Toast.LENGTH_SHORT).show() end) end) if not ok then postUi(function() prog.dismiss(); mostrarErrorDetallado("ERROR BORRAR RESEÑA", tostring(err)) end) end end).start() end
function abrirDialogoCalificar(arch) local function pedirNombreAleatorioYCalificar() if ROL=="invitado" then local layN=LinearLayout(ctxSafe()); layN.setOrientation(LinearLayout.VERTICAL); layN.setPadding(20,20,20,20) local tvN=TextView(ctxSafe()); tvN.setText("Ingresa un nombre aleatorio para tu calificación"); tvN.setTextColor(Color.WHITE); layN.addView(tvN) local edN=EditText(ctxSafe()); edN.setHint("Nombre aleatorio Ej: Usuario123"); layN.addView(edN) local fila=LinearLayout(ctxSafe()); fila.setOrientation(LinearLayout.HORIZONTAL) local bC=Button(ctxSafe()); bC.setText("CANCELAR"); bC.setLayoutParams(LinearLayout.LayoutParams(0,-2,1)) local bO=Button(ctxSafe()); bO.setText("CONTINUAR"); bO.setLayoutParams(LinearLayout.LayoutParams(0,-2,1)) fila.addView(bC); fila.addView(bO); layN.addView(fila) local dN=LuaDialog(ctxSafe()); dN.setView(layN); dN.show() local lC={}; function lC.onClick(v) dN.dismiss() end; bC.setOnClickListener(View.OnClickListener(lC)) local lO={}; function lO.onClick(v) local nombreAleatorio=tostring(edN.getText()):gsub("^%s+",""):gsub("%s+$","") if nombreAleatorio=="" then Toast.makeText(ctxSafe(),"Pon un nombre",Toast.LENGTH_SHORT).show(); return end dN.dismiss(); abrirDialogoCalificarInterno(arch, nombreAleatorio) end; bO.setOnClickListener(View.OnClickListener(lO)) else abrirDialogoCalificarInterno(arch, nil) end end pedirNombreAleatorioYCalificar() end
function abrirDialogoCalificarInterno(arch, nombreAleatorioInvitado) local lay=LinearLayout(ctxSafe()); lay.setOrientation(LinearLayout.VERTICAL); lay.setPadding(20,20,20,20) local tv=TextView(ctxSafe()); tv.setText("Calificar "..nombreVisible(arch.nombre)); tv.setTextColor(Color.WHITE); lay.addView(tv) if nombreAleatorioInvitado then local tv2=TextView(ctxSafe()); tv2.setText("Calificarás como: "..nombreAleatorioInvitado); tv2.setTextColor(Color.parseColor("#FF1DB954")); lay.addView(tv2) end local sp=Spinner(ctxSafe()); local opts=ArrayList(); opts.add("5 ★ - Excelente"); opts.add("4 ★ - Bueno"); opts.add("3 ★ - Regular"); opts.add("2 ★ - Malo"); opts.add("1 ★ - Pesimo"); sp.setAdapter(ArrayAdapter(ctxSafe(), android.R.layout.simple_spinner_dropdown_item, opts)); lay.addView(sp) local ed=EditText(ctxSafe()); ed.setHint("Comentario opcional"); lay.addView(ed) local fila=LinearLayout(ctxSafe()); fila.setOrientation(LinearLayout.HORIZONTAL) local bC=Button(ctxSafe()); bC.setText("CANCELAR"); bC.setLayoutParams(LinearLayout.LayoutParams(0,-2,1)) local bE=Button(ctxSafe()); bE.setText("ENVIAR"); bE.setLayoutParams(LinearLayout.LayoutParams(0,-2,1)) fila.addView(bC); fila.addView(bE); lay.addView(fila) local d=LuaDialog(ctxSafe()); d.setView(lay); d.show() local lC={}; function lC.onClick(v) d.dismiss() end; bC.setOnClickListener(View.OnClickListener(lC)) local lE={}; function lE.onClick(v) vibrar() local rating=5-sp.getSelectedItemPosition() local prog=mostrarProgreso("Enviando calificación...") Thread(function() local ok,err=pcall(function() local api="https://api.github.com/repos/"..REPO.."/contents/calificaciones.json"; local c=URL(api).openConnection(); c.setRequestMethod("GET"); c.setRequestProperty("Authorization","token "..TOKEN); local sha=""; local lista={} if c.getResponseCode()==200 then local br=BufferedReader(InputStreamReader(c.getInputStream())); local s=""; local l=br.readLine() while l~=nil do s=s..l; l=br.readLine() end br.close(); local obj=cjson.decode(s); sha=obj.sha; if obj.content then local dec=tostring(String(Base64.decode(obj.content,Base64.DEFAULT),"UTF-8")); local dl=cjson.decode(dec); if dl then lista=dl end end end local nueva={} for k,cal in ipairs(lista) do if not (cal.nombre:lower()==arch.nombre:lower() and (cal.usuario_lower or cal.usuario or ""):lower()==MI_USUARIO:lower()) then table.insert(nueva,cal) end end local nombreMostrar=MI_NOMBRE_PUBLICO if nombreAleatorioInvitado and nombreAleatorioInvitado~="" then nombreMostrar=nombreAleatorioInvitado end table.insert(nueva,{nombre=arch.nombre, usuario=nombreMostrar, usuario_lower=MI_USUARIO, estrellas=rating, comentario=tostring(ed.getText()), fecha=os.time()}); CALIFICACIONES_CACHE=nueva local newJson=cjson.encode(nueva); local enc=Base64.encodeToString(String(newJson).getBytes("UTF-8"),Base64.NO_WRAP); local put=URL(api).openConnection(); put.setRequestMethod("PUT"); put.setRequestProperty("Authorization","token "..TOKEN); put.setRequestProperty("Content-Type","application/json"); put.setDoOutput(true) local body={message="Calificar "..arch.nombre, content=enc, branch="main", sha=sha}; local os=put.getOutputStream(); os.write(String(cjson.encode(body)).getBytes("UTF-8")); os.flush(); os.close() postUi(function() prog.dismiss(); Toast.makeText(ctxSafe(),"Calificado: "..rating.." ★ como "..nombreMostrar,Toast.LENGTH_LONG).show() end) end) if not ok then postUi(function() prog.dismiss(); mostrarErrorDetallado("ERROR CALIFICAR", tostring(err)) end) end end).start() d.dismiss() end; bE.setOnClickListener(View.OnClickListener(lE)) end
function instalar(item) if not item or not item.nombre or not item.url or tostring(item.nombre)=="" then mostrarErrorDetallado("ERROR AL INSTALAR", "Datos del archivo inválidos\nnombre: "..tostring(item and item.nombre).."\nurl: "..tostring(item and item.url)) return end reproducirSonido("descargar.ogg") local base="/storage/emulated/0/解说/Plugins/" if item.categoria and item.categoria:lower():find("sonido") then base="/storage/emulated/0/解说/Sonidos/" end if item.categoria and item.categoria:lower():find("herramienta") then base="/storage/emulated/0/解说/Herramientas/" end if esComplementoReal(item.nombre, item.descripcion) then base="/storage/emulated/0/解说/Plugins/" end if tostring(item.nombre):lower():find("whatsapp sonidos tema") or tostring(item.nombre):lower():find("sonidos tema") then if not tostring(item.nombre):lower():find("creador") then base="/storage/emulated/0/解说/Sonidos/" end end local nombreSeguro=tostring(item.nombre) local limpio=nombreSeguro:match("(.+)%..+") or nombreSeguro if not limpio or limpio=="" then limpio="archivo_descargado" end local dest=base..limpio.."/" Toast.makeText(ctxSafe(),"Descargando "..nombreVisible(limpio),Toast.LENGTH_SHORT).show() task(function(url, path, nombreCarpeta) local ok,detalle=pcall(function() local f=File(path); if not f.exists() then f.mkdirs() end local conn=URL(url).openConnection() conn.setConnectTimeout(15000) conn.setReadTimeout(15000) conn.connect() local code=200 pcall(function() code=conn.getResponseCode() end) if code>=400 then error("Servidor respondió código "..code.." - URL: "..url) end local zip=ZipInputStream(conn.getInputStream()) local e=zip.getNextEntry() if not e then error("Archivo zip vacío o dañado desde servidor - URL: "..url) end while e do local name=e.getName() or "" if nombreCarpeta and #nombreCarpeta>0 and name:sub(1,#nombreCarpeta+1)==nombreCarpeta.."/" then name=name:sub(#nombreCarpeta+2) end if name~="" then local fp=path..name; local fl=File(fp) if e.isDirectory() then if not fl.exists() then fl.mkdirs() end else local par=fl.getParentFile(); if not par.exists() then par.mkdirs() end local fos=FileOutputStream(fl); local buf=byte[4096]; local l=zip.read(buf) while l>0 do fos.write(buf,0,l); l=zip.read(buf) end fos.close() end end zip.closeEntry(); e=zip.getNextEntry() end zip.close() end) if not ok then return false, detalle end return true, "ok" end, item.url, dest, limpio, function(s, detalle) if s then incrementarDescarga(item) postUi(function() hablar("Instalado correctamente") reproducirSonido("éxito.mp3") local lay=LinearLayout(ctxSafe()); lay.setPadding(20,20,20,20) local tv=TextView(ctxSafe()); tv.setText("Instalado correctamente."); tv.setTextColor(Color.WHITE); lay.addView(tv) local btn=Button(ctxSafe()); btn.setText("Entendido"); lay.addView(btn) local d=LuaDialog(ctxSafe()); d.setView(lay); d.setCancelable(false); d.show() local l={}; function l.onClick(v) d.dismiss() end; btn.setOnClickListener(View.OnClickListener(l)) end) else postUi(function() mostrarErrorDetallado("ERROR AL INSTALAR "..nombreVisible(item.nombre), tostring(detalle or "Error desconocido de servidor o código")) end) end end) end
function abrirDialogoSubida(cat,esEdit,nombreOrig) if ROL=="invitado" then Toast.makeText(ctxSafe(),"Invitados no pueden subir - solo descargar, calificar y leer avisos",Toast.LENGTH_LONG).show(); return end if ROL=="visitante" then Toast.makeText(ctxSafe(),"Inicia sesión como administrador para subir",Toast.LENGTH_SHORT).show(); return end if ROL=="admin" and esEdit then local encontrado=nil for _,it in ipairs(ARCHIVOS_CACHE) do if it.nombre:lower()==nombreOrig:lower() then encontrado=it; break end end if encontrado then if (encontrado.autor_lower or ""):lower()~=MI_USUARIO:lower() then Toast.makeText(ctxSafe(),"No puedes editar archivos de otros - solo los de tu perfil",Toast.LENGTH_LONG).show() return end end end local esSonido=cat:lower():find("sonido")~=nil if esSonido and cat=="Complementos" then esSonido=false end local lay=LinearLayout(ctxSafe()); lay.setOrientation(LinearLayout.VERTICAL); lay.setPadding(20,20,20,20); local tv=TextView(ctxSafe()); if esEdit then tv.setText("EDITAR "..cat) else tv.setText("SUBIR "..cat.." A "..perfilActual) end; tv.setTextColor(Color.parseColor("#FF1DB954")); lay.addView(tv) local edDesc=nil if not esSonido then edDesc=EditText(ctxSafe()); edDesc.setHint("Descripcion"); lay.addView(edDesc) else local tvInfo=TextView(ctxSafe()); tvInfo.setText("Tema de sonido - sin descripción"); tvInfo.setTextColor(Color.GRAY); lay.addView(tvInfo) end local lbl=TextView(ctxSafe()); lbl.setText("Ningun archivo"); lbl.setTextColor(Color.GRAY); lay.addView(lbl) local ruta={}; ruta[1]=nil; local btnElegir=Button(ctxSafe()); if esEdit then btnElegir.setText("Reemplazar archivo opcional") else btnElegir.setText("Elegir carpeta local") end; lay.addView(btnElegir) local fila=LinearLayout(ctxSafe()); fila.setOrientation(LinearLayout.HORIZONTAL); local bCan=Button(ctxSafe()); bCan.setText("CANCELAR"); bCan.setLayoutParams(LinearLayout.LayoutParams(0,-2,1)); local bOk=Button(ctxSafe()); if esEdit then bOk.setText("GUARDAR") else bOk.setText("SUBIR") end; bOk.setBackgroundColor(Color.parseColor("#FF1DB954")); bOk.setTextColor(Color.WHITE); bOk.setLayoutParams(LinearLayout.LayoutParams(0,-2,1)); fila.addView(bCan); fila.addView(bOk); lay.addView(fila) local d=LuaDialog(ctxSafe()); d.setView(lay); d.show() local lCan={}; function lCan.onClick(v) d.dismiss() end; bCan.setOnClickListener(View.OnClickListener(lCan)) local lElegir={}; function lElegir.onClick(v) local layExp=LinearLayout(ctxSafe()); layExp.setOrientation(LinearLayout.VERTICAL); layExp.setPadding(10,10,10,10); local tvS=TextView(ctxSafe()); tvS.setText("Leyendo..."); layExp.addView(tvS); local lv=ListView(ctxSafe()); layExp.addView(lv); local dlgExp=LuaDialog(ctxSafe()); dlgExp.setView(layExp); dlgExp.show() Thread(function() local lista={} local bases={"/storage/emulated/0/解说/Plugins"} if cat:lower():find("sonido") then bases={"/storage/emulated/0/解说/Sonidos"} end if cat:lower():find("herramienta") then bases={"/storage/emulated/0/解说/Herramientas"} end for k,base in ipairs(bases) do local subs=listarSubdirectorios(base) for j,s in ipairs(subs) do table.insert(lista,s) end end postUi(function() tvS.setText("Encontrados: "..#lista); local noms=ArrayList() for k,v in ipairs(lista) do noms.add(nombreVisible(v.name)) end; local adapter=ArrayAdapter(ctxSafe(), android.R.layout.simple_list_item_1, noms); lv.setAdapter(adapter); local lItem={}; function lItem.onItemClick(p,v,pos,id) local sel=lista[pos+1]; local tmp=sel.path.."/../temp"; File(tmp).mkdirs(); local zipPath=tmp.."/"..sel.name..".zip"; compressFolder(sel.path, zipPath); ruta[1]=zipPath; lbl.setText("Sel: "..nombreVisible(sel.name)..".zip"); dlgExp.dismiss() end; lv.setOnItemClickListener(AdapterView.OnItemClickListener(lItem)) end) end).start() end; btnElegir.setOnClickListener(View.OnClickListener(lElegir)) local lOk={}; function lOk.onClick(v) if not esEdit and not ruta[1] then Toast.makeText(ctxSafe(),"Elige archivo",Toast.LENGTH_SHORT).show(); return end local descTexto="" if edDesc then descTexto=tostring(edDesc.getText()) if descTexto=="" then Toast.makeText(ctxSafe(),"Pon descripcion",Toast.LENGTH_SHORT).show(); return end else descTexto="Tema de sonido" end d.dismiss(); subirAGitHub(cat, ruta[1], descTexto, "", esEdit, nombreOrig, function() mostrarCategorias() end) end; bOk.setOnClickListener(View.OnClickListener(lOk)) end
function mostrarLogin()
  YA_RECUPERADO=false ARCHIVOS_CACHE={} PERFILES_CACHE={}
  local prefs=obtenerPrefs()
  if prefs.getBoolean("guardar_sesion",false) then
    local guardado=prefs.getString("usuario_guardado","")
    local rolGuardado=prefs.getString("rol_guardado","visitante")
    local nombreGuardado=prefs.getString("nombre_guardado","")
    if guardado~="" then
      MI_USUARIO=guardado
      ROL=rolGuardado
      MI_NOMBRE_PUBLICO=nombreGuardado~="" and nombreGuardado or guardado
      if ROL=="invitado" then hablar("cargando servidor, sesión de invitado guardada") else hablar("cargando servidor, sesión guardada") end
      asegurarArchivosRepo(function() verificarPerfil(function() mostrarInterfaz() end) end)
      return
    end
  end
  local lay=LinearLayout(ctxSafe()); lay.setOrientation(LinearLayout.VERTICAL); lay.setPadding(30,30,30,30); lay.setBackgroundColor(Color.parseColor("#FF121212"))
  local tvT=TextView(ctxSafe()); tvT.setText("App Store Company - Login"); tvT.setTextColor(Color.WHITE); tvT.setTextSize(18); tvT.setGravity(Gravity.CENTER); lay.addView(tvT)
  local edit=EditText(ctxSafe()); edit.setHint("Ingresa tu nombre de usuario (interno o público) - Solo administradores"); edit.setTextColor(Color.WHITE); edit.setHintTextColor(Color.GRAY); lay.addView(edit)
  local layCheck=LinearLayout(ctxSafe()); layCheck.setOrientation(LinearLayout.HORIZONTAL); layCheck.setPadding(0,10,0,10)
  local check=CheckBox(ctxSafe()); check.setChecked(true)
  local tvCheck=TextView(ctxSafe()); tvCheck.setText("Guardar datos"); tvCheck.setTextColor(Color.WHITE); tvCheck.setPadding(10,0,0,0)
  layCheck.addView(check); layCheck.addView(tvCheck); lay.addView(layCheck)
  local btn=Button(ctxSafe()); btn.setText("ENTRAR"); btn.setBackgroundColor(Color.parseColor("#FF1DB954")); btn.setTextColor(Color.WHITE); lay.addView(btn)
  local btnInv=Button(ctxSafe()); btnInv.setText("ENTRAR COMO INVITADO (solo descargar/calificar/avisos)"); btnInv.setBackgroundColor(Color.parseColor("#FF444444")); btnInv.setTextColor(Color.WHITE); lay.addView(btnInv)
  local dlg=LuaDialog(ctxSafe()); dlg.setView(lay); dlg.setCancelable(false); dlg.show()
  local function guardarSesion()
    if check.isChecked() then
      local ed=prefs.edit() ed.putBoolean("guardar_sesion", true) ed.putString("usuario_guardado", MI_USUARIO) ed.putString("rol_guardado", ROL) ed.putString("nombre_guardado", MI_NOMBRE_PUBLICO) ed.apply()
    else
      local ed=prefs.edit() ed.putBoolean("guardar_sesion", false) ed.remove("usuario_guardado") ed.remove("rol_guardado") ed.remove("nombre_guardado") ed.apply()
    end
  end
  local lEntrar={}; function lEntrar.onClick(v)
    local u=tostring(edit.getText()); u=u:gsub("^%s+",""):gsub("%s+$","")
    if u=="" then Toast.makeText(ctxSafe(),"Ingresa tu nombre de usuario",Toast.LENGTH_SHORT).show(); return end
    MI_USUARIO=u:lower(); ROL="visitante"; MI_NOMBRE_PUBLICO=MI_USUARIO; YA_RECUPERADO=false; guardarSesion(); hablar("cargando servidor"); dlg.dismiss(); asegurarArchivosRepo(function() verificarPerfil(function() mostrarInterfaz() end) end)
  end; btn.setOnClickListener(View.OnClickListener(lEntrar))
  local lInv={}; function lInv.onClick(v)
    local idGuardado=prefs.getString("usuario_guardado",""); local rolGuardado=prefs.getString("rol_guardado","")
    if idGuardado~="" and rolGuardado=="invitado" then MI_USUARIO=idGuardado else MI_USUARIO="invitado_"..os.time()..math.random(100,999) end
    ROL="invitado"; MI_NOMBRE_PUBLICO="Invitado"; YA_RECUPERADO=false; guardarSesion(); hablar("Entrando como invitado"); dlg.dismiss(); asegurarArchivosRepo(function() verificarPerfil(function() mostrarInterfaz() end) end)
  end; btnInv.setOnClickListener(View.OnClickListener(lInv))
end
mostrarLogin()