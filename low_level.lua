env.info("KTZ_PIT: chargement des fonctions de bas niveau")

k.file_exists = function(p)
	env.info("test de l'existence du fichier: "..p)
	local f=io.open(p,'r')
	if f~=nil then io.close(f)
		env.info("le fichier existe")
		return true
	else
		env.info("le fichier n'existe pas")
		return false
	end
end

old_dofile = dofile
new_dofile = function(p)
	env.info("chargement du fichier: "..p)
	old_dofile(p)
	env.info("fichier chargé")
end
dofile = new_dofile

env.info("KTZ_PIT: chargement des fonctions de bas niveau réussi")
