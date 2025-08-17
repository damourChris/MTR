using Test
using CellTypeDeconvolutionFrameworkV5

@testset "CellTypeDeconvolutionFrameworkV5 Basic Tests" begin
    @testset "Module Loading" begin
        @test isa(CellTypeDeconvolutionFrameworkV5, Module)
        @test isdefined(CellTypeDeconvolutionFrameworkV5, :AbstractRepository)
        @test isdefined(CellTypeDeconvolutionFrameworkV5, :MemoryRepository)
    end

    @testset "Exception System" begin
        # Test that exceptions can be created
        @test_nowarn DataValidationError("test", "field", "expected", "actual")
        @test_nowarn RepositoryAccessError("test", "read", "key", nothing, "suggestion")
        @test_nowarn CacheCorruptionError("test", "key", "path", "type", nothing, nothing)
        @test_nowarn MemoryLimitExceededError("test", 1.0, 2.0, "op", 0.5, String[])
    end

    @testset "Preferences System" begin
        # Test basic preference functions exist
        @test isa(get_repository_memory_limit_gigabytes(), Float64)
        @test isa(get_cache_eviction_threshold_ratio(), Float64)
        @test isa(get_gene_correlation_threshold_value(), Float64)
    end

    @testset "Memory Repository" begin
        # Test basic memory repository functionality
        repo = MemoryRepository(memory_limit_gb = 1.0)
        @test isa(repo, AbstractRepository)
        @test isa(repo, MemoryRepository)
        @test is_memory_repository(repo)
        @test !is_file_repository(repo)
        @test !is_composite_repository(repo)

        # Test basic operations
        @test !haskey(repo, "test_key")
        @test length(keys(repo)) == 0
        @test cache_size(repo) == 0
        @test memory_usage(repo) == 0.0

        # Test storing and retrieving data
        test_data = [1, 2, 3, 4, 5]
        repo["test_key"] = test_data
        @test haskey(repo, "test_key")
        @test repo["test_key"] == test_data
        @test length(keys(repo)) == 1

        # Test deletion
        delete!(repo, "test_key")
        @test !haskey(repo, "test_key")
        @test length(keys(repo)) == 0
    end

    @testset "Utility Functions" begin
        # Test hash generation
        params = Dict("test" => "value", "number" => 42)
        hash1 = generate_cache_key(params)
        hash2 = generate_cache_key(params)
        @test hash1 == hash2  # Should be deterministic
        @test length(hash1) == 64  # SHA256 hex length

        # Test key validation
        @test validate_repository_key("valid/key")
        @test validate_repository_key("valid_key")
        @test validate_repository_key("valid-key")
        @test !validate_repository_key("")
        @test !validate_repository_key("/invalid")
        @test !validate_repository_key("invalid/")

        # Test key normalization
        @test normalize_repository_key("Test Key") == "test_key"
        @test normalize_repository_key("UPPER") == "upper"
    end

    @testset "Configuration Functions" begin
        # Test configuration retrieval
        @test isa(get_all_v5_preferences(), Dict{String, Any})

        # Test memory limit functions
        original_limit = get_repository_memory_limit_gigabytes()
        set_repository_memory_limit_gigabytes!(4.0)
        @test get_repository_memory_limit_gigabytes() == 4.0
        set_repository_memory_limit_gigabytes!(original_limit)  # Restore

        # Test correlation threshold functions
        original_threshold = get_gene_correlation_threshold_value()
        set_gene_correlation_threshold_value!(0.5)
        @test get_gene_correlation_threshold_value() == 0.5
        set_gene_correlation_threshold_value!(original_threshold)  # Restore
    end
end
