"""
    duplicated(v::AbstractVector{T}) 

Find the indices of values that have appeared before in the vector.
# Example usage:
```jldoctest
julia> v = [1, 2, 3, 1, 4, 5, 6, 2]
julia> result = duplicated(v)
7-element Vector{Bool}:
 0
 0
 0
 1
 0
 0
 0
 1
```"""
function duplicated(v::AbstractVector{T}) where {T}
    seen = Set{T}()
    return [length(seen) !== length(push!(seen, x)) for x in v]
end
