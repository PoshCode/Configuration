# This requires vercel ncc:
#    npm i -g @vercel/ncc
foreach ($source in Get-ChildItem $PSScriptRoot/src) {
    ncc build $source.FullName --minify --out  $PSScriptRoot/dist/$($source.BaseName) --license licenses.txt
}
Move-Item $PSScriptRoot/dist/action/* $PSScriptRoot -force
