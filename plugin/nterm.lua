if vim.g.loaded_nterm then return end
vim.g.loaded_nterm = true
require('nterm').setup()
