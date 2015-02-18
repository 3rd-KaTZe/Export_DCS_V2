-------------------------------------------------------------------------------
-- Logging & debug
k.debug = true
k.log_file = nil -- fichier log
k.log = function (message)

	-- Création du fichier de log des communication serveur, s'il n'existe pas
	-- Format , KTZ-SIOC3000_ComLog-yyyymmdd-hhmm.csv
	--
	if k.debug then
		
		if not k.log_file then
			-- création du fichier log si nécessaire
       			k.log_file = io.open(lfs.writedir().."Logs\\KatzePit\\KTZ-SIOC5010_ComLog-"..os.date("%Y%m%d-%H%M")..".csv", "w")
				
			-- Ecriture de l'entète dans le fichier
			if k.log_file then
				k.log_file:write("*********************************************;\n")
				k.log_file:write("*     Fichier Log des Communications SIOC   *;\n")
				k.log_file:write("*     Par KaTZe  -  http://www.3rd-wing.net *;\n")
				k.log_file:write("*     Version FC3  du 02/02/2015            *;\n")
				k.log_file:write("*********************************************;\n\n")
			end
			
		end
	
		-- Ecriture des données dans le fichier existant
		if k.log_file then
			k.log_file:write(string.format(" %s ; %s",os.clock(),message),"\n")
		end
	end
end

k.log("module de logging chargé")
