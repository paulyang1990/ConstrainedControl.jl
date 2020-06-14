# TODO
# Only for constant reference trajectories
# Only for 1dof joints
# Only finite horizon
mutable struct LQR{T,N,Nb12} <: Controller
    K::Vector{Vector{SMatrix{1,Nb12,T,Nb12}}} # for each time step and each eqc

    xd::Vector{SVector{3,Float64}}
    vd::Vector{SVector{3,Float64}}
    qd::Vector{UnitQuaternion{T}}
    ωd::Vector{SVector{3,Float64}}

    eqcids::Vector{Integer}
    Fτd::Vector{SVector{1,Float64}}

    control!::Function


    function LQR(mechanism::Mechanism{T,Nn,Nb}, bodyids::AbstractVector{<:Integer}, eqcids::AbstractVector{<:Integer},
            Q::Vector{<:AbstractMatrix{T}}, R::Vector{<:AbstractMatrix{T}}, horizon;
            xd::Vector{<:AbstractVector{T}} = [SA{T}[0; 0; 0] for i=1:Nb], 
            vd::Vector{<:AbstractVector{T}} = [SA{T}[0; 0; 0] for i=1:Nb],
            qd::Vector{UnitQuaternion{T}} = [one(UnitQuaternion{T}) for i=1:Nb], 
            ωd::Vector{<:AbstractVector{T}} = [SA{T}[0; 0; 0] for i=1:Nb],
            Fτd::Vector{<:AbstractVector{T}} = [SA{T}[0] for i=1:length(eqcids)]
        ) where {T, Nn, Nb}

        @assert length(bodyids) == length(Q) == length(xd) == length(vd) == length(qd) == length(ωd) == Nb "Missmatched length for bodies"
        @assert length(eqcids) == length(R) == length(Fτd) "Missmatched length for constraints"
        @assert horizon < Inf "Infinite horizon not supported"

        Δt = mechanism.Δt
        
        N = horizon/Δt
        if N<Inf
            N = Integer(ceil(horizon/Δt))
        end
        
        Q = cat(Q...,dims=(1,2))
        R = cat(R...,dims=(1,2))

        # linearize        
        A, B, G = linearsystem(mechanism, xd, vd, qd, ωd, Fτd, bodyids, eqcids)

        # calculate K
        K = dlqr(A, B, G, Q, R, N)
        
        new{T, N, Nb*12}(K, xd, vd, qd, ωd, eqcids, Fτd, control_lqr!)
    end
end

function control_lqr!(mechanism, lqr::LQR{T,N,Nb6}, k) where {T,N,Nb6}
    Δz = zeros(T,Nb6)
    for (id,body) in enumerate(mechanism.bodies)
        colx = (id-1)*12+1:(id-1)*12+3
        colv = (id-1)*12+4:(id-1)*12+6
        colq = (id-1)*12+7:(id-1)*12+9
        colω = (id-1)*12+10:(id-1)*12+12

        state = body.state
        Δz[colx] = state.xsol[2]-lqr.xd[id]
        Δz[colv] = state.vsol[2]-lqr.vd[id]
        Δz[colq] = ConstrainedDynamics.VLᵀmat(lqr.qd[id]) * Rotations.params(state.qsol[2])
        Δz[colω] = state.ωsol[2]-lqr.ωd[id]
    end

    if k<N
        for (i,id) in enumerate(lqr.eqcids)
            u = lqr.Fτd[i] - lqr.K[k][i]*Δz
            setForce!(mechanism, geteqconstraint(mechanism, id), u)
        end
    end

    return
end

function dlqr(A,B,G,Q,R,N)
    n = size(G)[1]
    m = size(B)[2]
    r = minimum([n;m])

    ZGU = zeros(n, m)
    K = [[zeros(1,size(Q)[1]) for j=1:m] for i=1:N-1]

    Pk = Q
    Hk = G

    for k=N-1:-1:1
        Mxxk = Q + A'*Pk*A
        Muuk = R + B'*Pk*B
        Muxk = B'*Pk*A

        Cxk = [G;Hk*A]
        Cuk = [ZGU;Hk*B]

        VSVDk = svd(Cuk, full=true).V
        Vck = VSVDk[:,1:r]
        Vuck = VSVDk[:,r+1:m]
        

        Kk = Vck*pinv(Cuk*Vck)*Cxk + Vuck/(Vuck'*Muuk*Vuck)*Vuck'*Muxk
        for i=1:m
            K[k][i] = Kk[i:i,:]
        end

        Pk = Mxxk - 2*Muxk'*Kk + Kk'*Muuk*Kk
        Hk = (I - Cuk*Vck*pinv(Cuk*Vck))*Cxk
    end

    return K
end

