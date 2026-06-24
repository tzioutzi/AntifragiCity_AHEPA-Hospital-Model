# AntifragiCity_AHEPA Hospital Model
Overview
The AHEPA Hospital Model is an agent-based Decision Support System pilot developed to study and optimize patient transit to the AHEPA tertiary hospital in Thessaloniki, Greece under varying traffic demand conditions and supply disruptions. The model forms part of AntifragiCity Deliverable D3.4 and serves as a sandbox for evaluating shuttle-based response strategies that can preserve or restore accessibility when urban mobility is degraded.
The model captures the traffic-informed underlay of the city of Thessaloniki — including its boundaries, expected traffic levels, and primary road network — and uses it to simulate how patients travel to the hospital amid both routine congestion and emergency-style disruptions.
________________________________________
Key Features

🚦 Realistic Traffic Underlay
•	Built on the TomTom Traffic Index for granular baseline traffic levels and travel durations across the city.
•	Models the primary road network with intersections as nodes and road segments as links, where intersections act as dynamic local congestion attractors.

👥 Agent-Based Design
•	Cars are autonomous agents with randomized origins and destinations within the city, acting as obstacles to the movement of patients.
•	Patients are autonomous agents that attempt to travel towards the hospital.
•	The AHEPA Hospital itself is modelled as an individual agent that serves as an attractor for the activity-based circulation of patients.

📊 Configurable Parameters & Scenarios
The end-user can define:
Parameter	Options
City-wide traffic	Average / Morning rush / Evening rush
Patient load	User-defined number of patients and origins 
Congestion around hospital	Variable intensity and spatial extent (radius) 
Road disruptions	Road segment closures along patient corridors 
Multi-factor incidents	Any combination of the above constraints

🎯 Strategy Evaluation
Three shuttle-based response strategies are available for investigation:
•	R1 — En-route shuttle operating within the patient origin area to collect and transport patients on a priority basis.
•	R2 — Shuttle deployed from the AHEPA Hospital to retrieve the patient and transport them on a priority basis.
•	R3 — Shuttle stationed in a low-traffic zone with dynamic routing.

📈 Built-in KPI Dashboard
The simulation tracks system capacity through KPIs defined in Deliverable D2.3:
•	Throughput (M) — flow of patients into the hospital.
•	Efficiency (S) — performance of the network under stress.
•	Redundancy (R) — availability of alternative pathways.
•	Entropy / Satisfaction (Q) — patients' psychological stress during transfer, based on AntifragiCity Deliverable D2.7 (KPI framework)
•	Energy KPI — fuel consumption tied to stop-and-go cycles (frequent decelerations/accelerations during congestion), expressed as a percentage difference from the system's initial states.
________________________________________
Empirical Foundation
The model's baseline parameters are grounded in real hospital records: AHEPA Hospital's incoming emergency admissions between January 2023 and September 2025 were processed to extract origin-destination matrices. Two key findings drive the design:
•	More than 80% of emergency admissions occur via personal transport (not ambulance).
•	The majority of admissions fall between 08:00 and 23:00, with hourly peaks coinciding with Thessaloniki's urban rush hours, necessitating a stochastic modelling of travel durations.
________________________________________
Demo Pilots in Context
Dimension	AHEPA Hospital
Mobility function examined	Patient self-transit to a tertiary hospital
Modes in the model	Private cars (patients + randomized traffic), shuttles
Disruption typology	Road segment closure; intensity- and radius-modulated congestion around the hospital 
Response strategies	R1: en-route shuttle; R2: hospital-deployed shuttle; R3: shuttle stationed in low-traffic zone with dynamic routing 
KPIs applied	Throughput (M), Efficiency (S), Redundancy (R), Entropy/Q + Energy KPI
________________________________________
Sample Insights
The model reveals that as the spatial extent of a congested area around the hospital grows, performance levels show saturation effects — once a critical congestion radius is reached, the network reaches a capacity limit where further spatial expansion yields diminishing marginal impacts on travel times. The origin points of patients do not appear to affect their speed reduction in this scenario, suggesting that congestion radius rather than location is the primary driver.
________________________________________
Citation
If you use this model in academic work, please cite the parent deliverable:
Tzioutziou, A., Tsami, M., Xenidis, Y., et al.. D3.4 Mobility Triage Analysis DSS. AntifragiCity Project .
