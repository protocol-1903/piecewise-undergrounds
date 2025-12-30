if not mods["matts-logistics"] then return end

data.raw["pipe-to-ground"]["matts-medium-pipe-to-ground"].pu_compat = {associated_pipe = "matts-pipe"}
data.raw["pipe-to-ground"]["matts-long-pipe-to-ground"].pu_compat = {associated_pipe = "matts-pipe"}
data.raw["pipe-to-ground"]["matts-ultra-pipe-to-ground"].pu_compat = {associated_pipe = "matts-pipe"}
data.raw["pipe-to-ground"]["matts-continental-pipe-to-ground"].pu_compat = {associated_pipe = "matts-pipe"}