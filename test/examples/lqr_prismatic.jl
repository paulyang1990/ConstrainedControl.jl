using ConstrainedDynamics
using ConstrainedControl
using LinearAlgebra


# Parameters
joint_axis = [1.0;0.0;0.0]

length1 = 1.0
width, depth = 0.1, 0.1

# Links
origin = Origin{Float64}()
link1 = Box(width, depth, width, length1)

# Constraints
joint_between_origin_and_link1 = EqualityConstraint(Prismatic(origin, link1, joint_axis))

links = [link1]
constraints = [joint_between_origin_and_link1]


mech = Mechanism(origin, links, constraints, g=0.)
setPosition!(origin,link1,Δx = [1.0;0;0])

Q = ones(1)
R = ones(1)

lqr = LQR(mech, getid.(constraints), getid.(constraints), Q, R, 10.)
@test true