@test_throws DimensionMismatch shuffleobs((X, rand(149)))

@testset "typestability" begin
    for var in vars
        @test typeof(@inferred(shuffleobs(var))) <: SubArray
    end
    for tup in tuples
        @test typeof(@inferred(shuffleobs(tup))) <: Tuple
    end
end

@testset "Array and SubArray" begin
    for var in vars
        @test size(shuffleobs(var)) == size(var)
    end
    # tests if all obs are still present and none duplicated
    @test sum(shuffleobs(Y1)) == 120
end

@testset "Tuple of Array and SubArray" begin
    for var in ((X,yv), (Xv,y), tuples...)
        @test_throws MethodError shuffleobs(var...)
        @test typeof(shuffleobs(var)) <: Tuple
        @test all(map(x->(typeof(x)<:SubArray), shuffleobs(var)))
        @test all(map(x->(numobs(x)===15), shuffleobs(var)))
    end
    # tests if all obs are still present and none duplicated
    # also tests that both paramter are shuffled identically
    x1, y1, z1 = shuffleobs((X1,Y1,X1))
    @test vec(sum(x1,dims=2)) == fill(120,10)
    @test vec(sum(z1,dims=2)) == fill(120,10)
    @test sum(y1) == 120
    @test all(x1' .== y1)
    @test all(z1' .== y1)
end

@testset "SparseArray" begin
    for var in (Xs, ys)
        @test typeof(shuffleobs(var)) <: SubArray
        @test numobs(shuffleobs(var)) == numobs(var)
    end
    # tests if all obs are still present and none duplicated
    @test vec(sum(getobs(shuffleobs(sparse(X1))),dims=2)) == fill(120,10)
    @test sum(getobs(shuffleobs(sparse(Y1)))) == 120
end

@testset "Tuple of SparseArray" begin
    for var in ((Xs,ys), (X,ys), (Xs,y), (Xs,Xs), (XX,X,ys))
        @test_throws MethodError shuffleobs(var...)
        @test typeof(shuffleobs(var)) <: Tuple
        @test numobs(shuffleobs(var)) == numobs(var)
    end
    # tests if all obs are still present and none duplicated
    # also tests that both paramter are shuffled identically
    x1, y1 = getobs(shuffleobs((sparse(X1),sparse(Y1))))
    @test vec(sum(x1,dims=2)) == fill(120,10)
    @test sum(y1) == 120
    @test all(x1' .== y1)
end

# @testset "ObsView" begin
#     # tests if all obs are still present and none duplicated
#     ov = @inferred shuffleobs(obsview(X1))
#     @test ov isa ObsView
#     x1 = getobs(ov)
#     @test sum(x1) == fill(120,10)
#     # also tests that both paramter are shuffled identically
#     ov = @inferred shuffleobs(obsview((X1,X1)))
#     @test ov isa ObsView
#     x1 = getobs(ov)
#     for i = 1:length(x1)
#         @test x1[i][1] == x1[i][2]
#     end
#     for i = 1:2
#         @test sum(getindex.(x1,i)) == fill(120,10)
#     end
# end

# @testset "BatchView" begin
#     # tests if all obs are still present and none duplicated
#     bv1 = batchview(X1, 30)
#     bv = @inferred shuffleobs(bv1)
#     @test length(bv) == length(bv1)
#     @test bv isa BatchView{<:SubArray,<:SubArray}
#     @test vec(sum(sum(bv),dims=2)) == fill(120,10)
# end

@testset "RNG" begin
    # tests reproducibility
    explicit_shuffle = shuffleobs(MersenneTwister(42), (X, y))
    @test explicit_shuffle == shuffleobs(MersenneTwister(42), (X, y))
end
