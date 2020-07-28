using ConstrainedDynamics
using ConstrainedControl
using LinearAlgebra
using Rotations


# Parameters
ex = [1.0;0.0;0.0]
ey = [0.0;1.0;0.0]
p2 = [0.0;0.0;length1/2] # joint connection point

length1 = 1.0
width, depth = 0.1, 0.1
cartshape = Box(0.1, 0.5, 0.1, length1/2)
poleshape = Box(width, depth, length1, length1)

# Desired orientation
ϕ = 0.

# Number of links
N = 3
ϕinit = rand(N)/(3^N)
yinit = rand()-0/5

# Links
origin = Origin{Float64}()
cart = Body(cartshape)
bodies = [cart; [Body(poleshape) for i = 1:N]]

# Constraints
joint1 = EqualityConstraint(Prismatic(origin, cart, ey))
joint2 = EqualityConstraint(Revolute(cart, bodies[2], ex; p2=-p2))
constraints = [joint1; joint2]
if N > 1
    constraints = [constraints; [EqualityConstraint(Revolute(bodies[i], bodies[i+1], ex; p1 = p2, p2=-p2)) for i=2:N]]
end

shapes = [cartshape;poleshape]


mech = Mechanism(origin, bodies, constraints, shapes = shapes, g=-9.81)
setPosition!(origin,cart,Δx = [0;yinit;0])
setPosition!(cart,bodies[2],p2 = -p2,Δq = UnitQuaternion(RotX(ϕinit[1])))
for i=2:N
    setPosition!(bodies[i],bodies[i+1],p1=p2,p2=-p2,Δq=UnitQuaternion(RotX(ϕinit[i])))
end

xd = [[[0;0;0.0]]; [[0;0;i-1+0.5] for i=1:N]]

Q = [diagm(ones(12))*1.0 for i=1:N+1]
R = [ones(1,1)]

lqr = LQR(mech, getid.(bodies), [getid(constraints[1])], Q, R, 10., xd=xd)
@test true