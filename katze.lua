package.path  = package.path..";./LuaSocket/?.lua"
package.cpath = package.cpath..";./LuaSocket/?.dll"

k = {} -- table principale
k.debug = true
k.dir = {}
k.dir.main = lfs.writedir().."/Scripts"
k.dir.logs = lfs.writedir().."/Logs/KatzePit"
k.config = {}
k.sioc = {}
k.loop = {} -- boucles d'export
k.loop = {}
k.loop.fast = nil
k.loop.slow = nil
k.ka50 = {}
k.ka50.export = {}
k.mi8 = {}
k.mi8.export = {}
k.uh1 = {}
k.uh1.export = {}
k.fc3 = {}
k.fc3.export = {}
k.loop.sample = {}
k.loop.sample.fast = nil
k.loop.sample.slow = nil
k.loop.sample.fps = nil
k.loop.next_sample = {}
k.loop.next_sample.fast = nil
k.loop.next_sample.slow = nil
k.loop.next_sample.fps = nil
k.loop.start_time = nil
k.loop.current_time = nil
k.loop.fps_counter = {}
k.loop.fps_counter.tot = 0

dofile(lfs.writedir().."/Scripts/low_level.lua")

env.info("KTZ_PIT: chargement du module \"logging\"")
dofile(k.dir.main.."/logging.lua")
k.info("module logging chargé")

k.info("chargement du fichier de configuration")
dofile ( lfs.writedir().."Scripts\\siocConfig.lua" ) -- parsing des options

k.config.sioc.fast = (k.config.sioc.fast or 100) / 1000 -- intervalle boucle d'export rapide
k.log("fast: "..k.config.sioc.fast)

k.config.sioc.slow = (k.config.sioc.slow or 500) / 1000 -- intervalle boucle d'export lente
k.log("slow: "..k.config.sioc.slow)

k.config.sioc.ip = k.config.sioc.ip or "127.0.0.1" -- IP serveur SIOC
k.log("sioc ip: "..k.config.sioc.ip)

k.config.sioc.port = k.config.sioc.port or 8092 -- port serveur SIOC
k.log("sioc port: "..k.config.sioc.port)

k.config.fps = k.config.fps or 5 -- intervalle échantillonages FPS
k.log("intervalle FPS: "..k.config.fps)

k.info("configuration chargée")

dofile(lfs.writedir().."Scripts\\sioc.lua")
dofile(lfs.writedir().."Scripts\\low_level.lua")


k.mission_start = function()
	k.log("début d'une nouvelle mission")
	k.log("remise à zéro des compteurs de FPS")
	k.loop.fps = {}
	k.loop.fps[10] = 0
	k.loop.fps[20] = 0
	k.loop.fps[30] = 0
	k.loop.fps[40] = 0
	k.loop.fps[50] = 0
	k.loop.fps[60] = 0
	-- Mise à zero du panel armement dans SIOC
	
	k.log("test de la connexion avec SIOC")
	if k.sioc.ok then
		k.log("SIOC est connecté")
		if k.exportFC3done then
			k.log("remise à zéro du panel d'armement de FC3")
			k.fc3.weapon_init()
		end
		k.log("envoi à SIOC de l'heure de début de mission")
		k.sioc.send(41,k.loop.start_time)
	else
		k.log("SIOC n'est pas connecté")
	end
end

k.mission_end = function()
	k.log("  ","\n")
	k.log("--- Initialisation du Séquenceur ---" ,"\n")
	k.log(string.format(" Mission Start Time (secondes) = %.0f",k.loop.start_time,"\n"))	
	k.log(string.format(" Sampling Period 1 = %.1f secondes",k.loop.sample.fast,"\n"))
	k.log(string.format(" Sampling Period 2 = %.1f secondes",k.loop.sample.slow,"\n"))
	k.log(string.format(" Sampling Period FPS = %.1f secondes",k.loop.sample.fps,"\n"))
	-- imprimer l'histogramme FPS ??
end


k.log("tentative de connexion à SIOC")
-- if pcall(k.sioc.connect) then
k.sioc.connect()
if k.sioc.ok then
	k.log("SIOC connecté")
	k.loop.sample.fast = k.config.sioc.fast
	k.loop.sample.slow = k.config.sioc.slow
	k.loop.sample.fps = k.config.sioc.fps
	k.loop.start_time = LoGetMissionStartTime()
	k.loop.current_time = LoGetModelTime()
		
	k.loop.next_sample.fast = k.loop.current_time + k.loop.sample.fast
	k.loop.next_sample.slow = k.loop.current_time + k.loop.sample.slow
	k.loop.next_sample.fps = k.loop.current_time + k.loop.sample.fps

	k.log("chargement des overload")
	dofile(lfs.writedir().."/Scripts/overload.lua")
else
	k.log("erreur lors de la tentative de connexion")
end

k.file = {
	lfs.writedir().."/Scripts/KTZ_SIOC_FC3.lua",
	lfs.writedir().."/Scripts/KTZ_SIOC_Mi8.lua",
	lfs.writedir().."/Scripts/KTZ_SIOC_UH1.lua",
	lfs.writedir().."/Scripts/KTZ_SIOC_KA50.lua"
}


k.log("import des fichiers d'exports pour chaque pit")
for i=1, #k.file, 1 do
	f = k.file[i]
	k.log("test de l'existence de "..f)
	if k.file_exists(f) then
		k.log(f.." existe, chargement")
		dofile(f)
	end
end
