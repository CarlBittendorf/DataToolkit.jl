module FilePathsBaseExt

using FilePathsBase

using DataToolkitCore
import DataToolkitCore: load, save, getstorage, putstorage

# Storage/loaders provide the concrete `FilePath`/`DirPath`, not the abstract
# `SystemPath`, so both concrete forms are tried.
function getstorage(store::S, ::Type{AbstractPath}) where {S <: DataStorage}
    sp = @something(storage(store, FilePath, write=false),
                    storage(store, DirPath, write=false), Some(nothing))
    if !isnothing(sp) parse(AbstractPath, sp.path) end
end

function putstorage(store::S, path::AbstractPath) where {S <: DataStorage}
    P = if isdirpath(path) DirPath else FilePath end
    storage(store, P, write=true)
end

function load(loader::L, from::F, ::Type{AbstractPath}) where {L <: DataLoader, F}
    tryload(P) = if hasmethod(load, Tuple{L, F, Type{P}}) load(loader, from, P) end
    parse(AbstractPath, @something(tryload(FilePath), tryload(DirPath), return).path)
end

# Resolve ambiguity between the chain loader's load(::DataLoader{:chain}, ::Any, ::Type{T})
# and this extension's load(::DataLoader, ::Any, ::Type{AbstractPath}).
load(loader::DataLoader{:chain}, from, ::Type{AbstractPath}) =
    invoke(load, Tuple{DataLoader{:chain}, Any, Type{<:AbstractPath}}, loader, from, AbstractPath)

# The julia loader's two base methods are also ambiguous with this extension's
# generic AbstractPath load: each wins on one argument (`from::Any`/`::Nothing`
# vs the loader name, and `R::Type` vs `::Type{AbstractPath}`), so Julia cannot
# pick either. This extension method must therefore cover both input shapes.
#
# Delegating with `R = AbstractPath` is not safe: the base methods assert their
# result `::R` and throw when the user function produces a non-AbstractPath
# value (e.g. a DataFrame from passthrough storage), aborting an unqualified
# `read` before it can try other candidate types. Instead delegate with
# `R = Any` so the typeassert trivially passes, and honour the loaders'
# no-result contract by returning `nothing` when the produced value is not
# actually an AbstractPath; the untyped read machinery then continues to the
# next candidate type. The null-input base method already returns `nothing`
# for an empty `input` parameter, which `something`/`isnothing` treats the
# same as an explicit no-result.
load(loader::DataLoader{:julia}, ::Nothing, ::Type{AbstractPath}) = begin
    result = load(loader, nothing, Any)
    result isa AbstractPath ? result : nothing
end

load(loader::DataLoader{:julia}, from, ::Type{AbstractPath}) = begin
    result = invoke(load,
                    Tuple{DataLoader{:julia}, Any, Type{Any}},
                    loader, from, Any)
    result isa AbstractPath ? result : nothing
end

end
