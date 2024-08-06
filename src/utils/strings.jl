function is_loosely_the_same(str1::AbstractString, str2::AbstractString)::Bool
    # Normalize case
    str1_normalized = lowercase(str1)
    str2_normalized = lowercase(str2)

    # Normalize special characters (- and _)
    str1_normalized = replace(replace(str1_normalized, "-" => "_"), "_" => "_")
    str2_normalized = replace(replace(str2_normalized, "-" => "_"), "_" => "_")

    # Compare normalized strings
    return str1_normalized == str2_normalized
end