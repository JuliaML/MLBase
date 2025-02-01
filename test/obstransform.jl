@testset "mapobs" begin
    data = 1:10
    mdata = mapobs(-, data)
    @test getobs(mdata, 8) == -8

    @test length(mdata) == 10
    @test numobs(mdata) == 10

    mdata2 = mapobs((-, x -> 2x), data)
    @test getobs(mdata2, 8) == (-8, 16)

    nameddata = mapobs((x = sqrt, y = log), data)
    @test getobs(nameddata, 10) == (x = sqrt(10), y = log(10))
    @test getobs(nameddata.x, 10) == sqrt(10)

    # colon
    @test mapobs(x -> 2x, [1:10;])[:] == [2:2:20;]

    @testset "batched = :auto" begin
        data = (a = [1:10;],)

        m = mapobs(data; batched=:auto) do x 
            @test x.a isa Int 
            return (; c = 2 .* x.a) 
        end[1]
        @test m == (; c = 2)
        m = mapobs(data) do x 
            @test x.a isa Vector{Int} 
            return (; c = 2 .* x.a) 
        end[1:2]
        @test m == (; c = [2, 4])

        # check that :auto is the default
        m = mapobs(data) do x 
            @test x.a isa Int 
            return (; c = 2 .* x.a) 
        end[1]
        @test m == (; c = 2)
        m = mapobs(data) do x 
            @test x.a isa Vector{Int} 
            return (; c = 2 .* x.a) 
        end[1:2]
        @test m == (; c = [2, 4]) 
    end

    @testset "batched = :always" begin
        data = (; a = [1:10;],)

        m = mapobs(data; batched=:always) do x 
            @test x.a isa Vector{Int} 
            return (; c = 2 .* x.a) 
        end[1]
        @test m == (; c = 2)
        m = mapobs(data; batched=:always) do x 
            @test x.a isa Vector{Int} 
            return (; c = 2 .* x.a) 
        end[1:2]
        @test m == (; c = [2, 4])
    end

    @testset "batched = :never" begin
        data = (; a = [1:10;],)
        m = mapobs(data; batched=:never) do x 
            @test x.a isa Int
            return (; c = 2 .* x.a) 
        end[1]
        @test m == (; c = 2)
        m = mapobs(data; batched=:never) do x 
            @test x.a isa Int 
            return (; c = 2 .* x.a) 
        end[1:2]
        @test m == [(; c = 2), (; c = 4)]
    end
end

@testset "filterobs" begin
    data = 1:10
    fdata = filterobs(>(5), data)
    @test numobs(fdata) == 5
end

@testset "groupobs" begin
    data = -10:10
    datas = groupobs(>(0), data)
    @test length(datas) == 2
end

@testset "joinobs" begin
    data1, data2 = 1:10, 11:20
    jdata = joinobs(data1, data2)
    @test getobs(jdata, 15) == 15

    data = joinobs(1:5, 6:10)
    @test data[5:6] == [5, 6]
    data = joinobs(ones(2, 3), zeros(2, 3))
    @test data[3:4] == [[1.0, 1.0], [0.0, 0.0]]

    @testset "joins of joins" begin
        data1, data2 = 1:10, 11:20
        data12 = joinobs(data1, data2)
        data3 = 21:30
        data123 = joinobs(data12, data3)
        @test getobs(data123, 15) == 15
        @test getobs(data123, 25) == 25
        @test length(data123) == 30
        @test data123.datas[1] == data1
        @test data123.datas[2] == data2
        @test data123.datas[3] == data3
    end

    @testset "join different types" begin
        data1 = 1:5
        data2 = ones(2, 3)
        data12 = joinobs(data1, data2)
        @test data12[3] == 3
        @test data12[6] == [1.0, 1.0]
    end
end

@testset "shuffleobs" begin
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

    @testset "RNG" begin
        # tests reproducibility
        explicit_shuffle = shuffleobs(MersenneTwister(42), (X, y))
        @test explicit_shuffle == shuffleobs(MersenneTwister(42), (X, y))
    end

end
