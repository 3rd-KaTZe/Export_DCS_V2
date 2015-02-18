env.info("KTZ_PIT: chargement du module \"sioc.lua\"")

env.info("KTZ_PIT: chargement des dépendandes pour le socket")
package.path  = package.path..";./LuaSocket/?.lua"
package.cpath = package.cpath..";./LuaSocket/?.dll"
env.info("KTZ_PIT: chargement des dépendandes pour le socket réussi")

k.sioc.ok = false -- "true" si le socket SIOC est connecté
k.sioc.socket = require("socket") -- socket SIOC client
k.sioc.buffer = {} -- tampon SIOC

k.sioc.connect = function () -- fonction de connection à sioc
	k.info("connexion à SIOC")
	-- on retombe sur les valeurs par défaut si on ne les trouve pas
	host = k.config.sioc.ip or "127.0.0.1"
	port = k.config.sioc.port or 8092
	k.log("connexion à SIOC: ip:"..host.." port:"..port)
	k.log("connexion à SIOC: ouverture du socket")
	k.sioc.socket = socket.try(socket.connect(host, port)) -- connect to the listener socket
	k.log("connexion à SIOC: socket.tcp-nodelay: true")
	k.sioc.socket:setoption("tcp-nodelay",true) -- set immediate transmission mode
	k.log("connexion à SIOC: socket.timeout: 0.1")
	k.sioc.socket:settimeout(.01) -- set the timeout for reading the socket)
------------------------------------------------------------------------
-- 	Offset de SIOC qui seront écoutés								  --
-- 	0001 = Commande générale										  --
-- 	0002 = Commande spéciale										  --
------------------------------------------------------------------------
	inputs = {}
	inputs [1]=1
	inputs [2]=2
	local x, i
    	local s = ""
	k.log("connexion à SIOC: création du handshake de SIOC")
	for x,i in pairs(inputs)
	do
	    s = s..x..":"
	end
	k.log("connexion à SIOC: handshake SIOC: "..s)
	k.log("connexion à SIOC: envoi du handshake à SIOC")
	socket.try(k.sioc.socket:send("Arn.Inicio:"..s.."\n"))
	k.sioc.contact = ("Arn.Inicio:"..s.."\n")
	k.sioc.msg = "INIT-->;" .. k.sioc.contact
	k.log("connexion à SIOC: contact: "..k.sioc.contact)
	k.log("connexion à SIOC: msg: "..k.sioc.msg)
	k.info("connexion à SIOC: réussie")
	k.sioc.ok = true
end

k.sioc.send = function (attr_int, val_int)
		-- Option possible : Décalage des exports vers une plage SIOC
		-- Indiquer dans siocConfig.lua la plage désirée
		-- newAtt = tonumber(strAttribut) + siocConfig.plageSioc
		local attr_str = tostring(attr_int)
		local val_str = string.format("%d",val_int)
		k.log("envoi SIOC: attrib: "..attr_str)
		k.log("envoi SIOC: valeur: "..val_str)
		if (val_str ~= k.sioc.buffer[attr_str]) then
			k.sioc.buffer[attr_str] = val_str ;
			local msg = string.format("Arn.Resp:%s=%.0f:\n", attr_str, val_str)
			k.log("envoi SIOC: msg à envoyer: "..msg)
			socket.try(k.sioc.socket:send(msg))
			k.log("envoi SIOC: msg envoyé")
		end		
end

k.sioc.receive = function ()
	k.log("réception SIOC")
	local msg_rec = k.sioc.socket:receive()
	if msg_rec then
		k.log("réception SIOC: message reçu: "..tostring(msg_rec))
		local s,l,typeMessage = string.find(msg_rec,"(Arn.%w+)");
		typeMessage = tostring(typeMessage);
		------------------------------------------------------------
		-- Les types de message acceptés :                        --
		--                                                        --
		-- Arn.Vivo   : Le serveur à reçu "Arn.Vivo": du client   -- 
		--              Le serveur répond "Arn.Vivo"              --
		--				Il s'agit de l'équivalent SIOC d'un		  --
		--				ping-pong.								  --
		--														  --
		-- Arn.Resp   : Message pour l'execution des commandes    --
		--              a noter que Arn.Resp:1=0: remets le       --
		--              cache valeur à 'nil' aussi aprés chaque   --
		--				commande exécuté                          --
		------------------------------------------------------------
		if typeMessage == "Arn.Resp" then
			k.log("réception SIOC: lecture du message")
			local s, e, msg = string.find(msg,"([%d:=-]+)")
			k.log("réception SIOC: message décomposé: "..msg)
			local l = e - s -- longueur totale du message
			k.log("réception SIOC: longueur du message: "..l)
			local x = 0 -- index de lecture (seek pointer)
			local cmd -- commande
			local chan_str, chan_int -- canal SIOC
			local val_str,val_int -- valeur envoyée par SIOC
			local b,d -- pointeurs de position dans la chaîne de caractères intermédiaire
			while x < l do
				_,b,cmd = string.find(msg,"([%d=-]+)", l)
				k.log("réception SIOC: commande: "..cmd)
				k.log("réception SIOC: longueur du morceau: "..b)
				_,d,chan_str = string.find(cmd, "([%d-]+)")
				chan_int = tonumber(chan_str)
				--logCom(string.format(" Offset = %.0f",chan,"\n"))
				_,_,val_str = string.find(cmd, "([%d-]+)",d+1)
				val_int = tonumber(val_str)
				-----------------------------------------------------------------
				-- Canal #1 : commande type FC2
				-----------------------------------------------------------------
				if chan_int == 1 and val_int ~= 0 then
					-- Envoi à LockOn, commande type Classique FC3
					k.log("réception SIOC: canal1, envoi de la valeur: "..val_str)
					LoSetCommand(val_int)
				end
				-----------------------------------------------------------------
				-- Canal #2 : Commande type DCS
				-----------------------------------------------------------------
				-- KaTZe Modif BS2, Commande codée sur 8 caracteres , TDDBBBPV
				-- T = Type de bouton
				-- DD = Device
				-- BBB = numero du bouton
				-- P = Pas du rotateur
				-- V = Valeur recu
				if chan_int ==2 and val_int > 0 then
					k.log("réception SIOC: canal2")
					bouton_type = tonumber(string.sub(val_str,1,1))
					device = tonumber(string.sub(val_str,2,3))
					bouton = tonumber(string.sub(val_str,4,6))
					pas = tonumber(string.sub(val_str,7,7))
					val = tonumber(string.sub(val_str,8,8))
					k.log(string.format("réception SIOC: canal2: device = %.0f",device,"\n"))
					k.log(string.format("réception SIOC: canal2: bouton = %.0f",bouton,"\n"))
					k.log(string.format("réception SIOC: canal2: type = %.0f",bouton_type,"\n"))
					k.log(string.format("réception SIOC: canal2: valeur = %.0f",val,"\n"))
					-----------------------------------------------------------------
					-- Type 1 : Simple On/Off
					if bouton_type == 1 then
						-- Type interrupteur deux voies
						-- Envoi à LockOn, commande Device, Bouton + 3000 , Argument
						k.log("réception SIOC: canal2: bouton_type1")
						GetDevice(device):performClickableAction(3000+bouton,val)
					end
					-----------------------------------------------------------------
					-- Type 2 : Simple On/Off avec Capot sur KA50 ... inutilisé sur Mi-8 ou UH-1
					-- La séquence capot/bouton/capot est créé en 3 commandes successives par javascript
					if bouton_type == 2 then
						-- Type interrupteur deux voies, avec capot , val = val * 1000
						-- On ouvre, bascule, ferme
						k.log("réception SIOC: canal2: bouton_type2")
						GetDevice(device):performClickableAction(3000+bouton+1,val)
						GetDevice(device):performClickableAction(3000+bouton,val)
						GetDevice(device):performClickableAction(3000+bouton+1,val)
					end
					-----------------------------------------------------------------
					-- Type 3 : 3 positions Bas/Mid/Haut
					if bouton_type == 3 then
						-- Type interrupteur 3 positions  -1 , 0 , +1
						-- On décale de -1 i.e. 0>>-1 , 1>>0 , 2>>1
						k.log("réception SIOC: canal2: bouton_type3")
						GetDevice(device):performClickableAction(3000+bouton,(val-1))
					end
					-----------------------------------------------------------------
					-- Type 4 : Rotateur Multiple (Décimal) ... 
					if bouton_type == 4 then
						-- Type interrupteur rotary , 0.0 , 0.1 , 0.2 , 0.3 , ...
						-- On envoie des valeur de 0 à X
						k.log("réception SIOC: canal2: bouton_type4")
						if pas < 2 then  -- Pas à 0 ou 1, incrément par 0.1
							k.log("réception SIOC: canal2: bouton_type4: pas < 2")
							GetDevice(device):performClickableAction(3000+bouton,val/10)
						elseif pas == 2 then -- Pas à 2 , incrément par 0.05
							k.log("réception SIOC: canal2: bouton_type4: pas == 2")
							GetDevice(device):performClickableAction(3000+bouton,val/20)
						end
					end
					-----------------------------------------------------------------
					-- Type 5 : Press Bouton ... commande suivie de mise à zero
					if bouton_type == 5 then
						-- Type interrupteur press bouton
						-- On envoie 1 puis zero
						k.log("réception SIOC: canal2: bouton_type5")
						GetDevice(device):performClickableAction(3000+bouton,val)
						GetDevice(device):performClickableAction(3000+bouton,val*0)
					end
					-----------------------------------------------------------------
					-- Type 6 : Rotateur Multiple (Décimal , Centré sur zero)
					if bouton_type == 6 then
						-- Rotateur centré sur 0 , pas de 0.1, décalage négatif de "pas"/10
						-- exemple si pas = 5 , alors 0 --> -0.5 , 1 --> -0.4 , ... 5 --> 0 , 9 --> 0.4
						k.log("réception SIOC: canal2: bouton_type6")
						GetDevice(device):performClickableAction(3000+bouton,val/10 - pas/10)
					end
					-----------------------------------------------------------------
					-- Type 7 : Rotateur Multiple (Centésimal)
					if bouton_type == 7 then
						-- Rotateur centesimal , incrément = ( 10 * pas + val )/ 100
						k.log("réception SIOC: canal2: bouton_type7")
						GetDevice(device):performClickableAction(3000+bouton,(pas * 10 + val)/100)
					end
				end
			
				x = b + 1 -- calage du pointeur sur la prochaine partie du message
				k.log("réception SIOC: nouveau pointeur: "..x)
			end
		else
			k.log("réception SIOC: message autre que \"Arn.Resp\"; message ignoré")
		end
	else
		k.info("réception SIOC: erreur lors de la lecture du socket")
	end
end

env.info("KTZ_PIT: chargement du module \"sioc.lua\" réussi")
