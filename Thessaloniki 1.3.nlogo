breed [roadnodes roadnode]       ;; entities of the road network
breed [cars car]                 ;; entities of private cars moving throughout the entire city
breed [hospital hosp]            ;; entity of the hospital as destination node and decision-making centre
breed [patients patient]         ;; entity of patients travelling to the hospital by their own means (private car or taxi)
breed [assistance assist]        ;; entity of vehicle to pick up incoming patients from road network

undirected-link-breed [rrr rr]       ;; edges of road network (connection road network nodes)
undirected-link-breed [recroad recr] ;; new edges introduced in the road subsystem after the recovery phase

roadnodes-own     [roadcapacity  ;; capacity measure of the nodes of the road network
                    road_factor  ;; average length of out-links of each node of the road network, used as a factor of performance
             road_utility_factor ;; average population's needs from the neighboring patches of each road node
                     my_r_links  ;; number of my-links of each road network's node
                               ]


turtles-own               [speed ;; speed of vehicles including private cars and / or buses based on the underlying traffic data
                       ref_speed ;; speed of vehicles at the beggining of the run
                   nodeneighbors ;; list of initial number of connections for each node of the entire system
                       nodelinks ;; list of number of connections for each node of the entire system
             original_neighborsR ;; number of road node's neighbors at the beginning of the run
                         priopop ;; popuation for each node calculated at the beginning of the run for the prioritization of recovery
                              ]

patches-own             [traffic ;; traffic variable indicating the flows based on current data
                     ref_traffic ;; baseline traffic levels calculated based on average traffic conditions from Tomtom congestion index
                original_traffic ;; initial traffic levels at the beginning of the simulation without extra congestion

                     population  ;; attribute related with the population's density
                  new_population ;; population-based utility measure affected by the system's performance loss
                               ]


globals        [roadcapacitylist ;; list of the capacity measure of the road subsystem
                          roadrm ;; capacity measure of interconnected road nodes
                   totalcapacity ;; capacity measure of the nodes of the entire system
               totalcapacitylist ;; list of the capacity measure of the entire system
              totalcapacitylevel ;; capacity percentage
              original_neighbors ;; number of each node's neighbors at the beginning of the run



  ;; Global variables for performance-based resilience calculation
                   recovery_tick ;; ticks after recovery is completed
                     initialperf ;; total capacity percentage before disturbance
                        distperf ;; min total capacity performance during the disturbance
                       finalperf ;; total capacity percentage after recovery
                       totalloss ;; total loss in the performance of the system (observed performance - initial performance)
                   totallosslist ;; list of differences (observed performance - initial performance) of the entire system
                      resilience ;; resilience measure defined by Bruneau et al. 2003 based on resilience triangle
                    z_resilience ;; resilience measure defined by Zobel 2011 R=1-(XT/2T*) based on resilience triangle
                  h-r_resilience ;; resilience measure defined by Henry & Ramirez-Marquez 2012


 ;; Global variables for entropy calculation
                       roadlinks ;; maximum possible road nodes' connections
                       sort-road ;; list of road nodes by turtle ID
                             p4r ;; probability of road nodes' connections to be the same as their initial connections
                             h4r ;; plogp for the road subsystem
                         ;entropy ;; measure of the Shannon entropy of the subsystems' nodes' connections over the total connections (EntropyExplorerTwoColors)
                     entropylist ;; list of entropy measures as recorded during the run
                            p41r ;; probability of road nodes' connections not to be the same as their initial connections (S. Lloyd's tutorial)
                            h41r ;; plogp for the road subsystem
                              sr ;; marginal entropy of the road subsystem
                     entropy_dep ;; mutual entropy of the etnire system (entropy 4) considering dependent disturbances of joint probabilities
                entropy_dep_list ;; list of entropy_dep measures as recorded during the run


  ;; Global variables for patients travel characterisitics
                 patients_speed  ;; average speed of patients towards the hospital based on traffic flow data
                patients_arrival ;; travel time of patients within the urban area based on the count of ticks and their average speed
       patients_travel_time_list ;; list of recorded patients' travel time duration based on arrival
            patients_travel_time ;;
                    patients_ETA ;; list of patients' estimated remaining time to arrival to the hospital

 ;; Global variables for traffic network assessment ;; AntifragiCity
                         ; ;; traffic variable indicating the flows based on current data
                     throughput ;; mobility throughput M(t) measures effective service delivery : cars that move / total cars per tick
                         stress ;; stress S(t) captures congestion induced degradation - difference in speeds between average and current state: % change from ref_traffic
                     redundancy ;; redundancy R(t) provides alternative pathways: dormant links / active links (pre-event)
                        entropy ;; information entropy C(t) quantifies flow distribution diversity: C= sum ln(speed) and overall entropy normalized: C / Cmax
                 speed_rec_list ;; list of speeds recorded by each vehicle to identify maximum
                      max_speed ;; maximum speed observed for each vehicle
                    max_entropy ;; maximum speed information entropy Cmax = sum ln(max speed) of each vehicle
                   satisfaction ;; difference % in average patients' speed compared to average speed of cars in network
                        teleCom ;; Telecom network uptime during event: traffic signals (current roadnodes / total roadnodes)
                         energy ;; change (%) in energy consumption rates, increased consumptions in lower speeds in congestion setting: (current speed - 1) / average speed of each vehicle

                               ]

;;;; VARIABLES REPRESENTED IN THE INTERFACE TAB
                  ;; traffic_load : selection of traffic load mapping as underlay for the agents' world. Selection among Tomtom traffic index maps for "morning_rush", "average", and "evening_rush" for Thessaloniki
                ;; patient_density: number of patients per specific reference area (m2), used to estimate their flow in the road network
                  ;; show_gradient: switch to control the appearance of the gradient map of population density attribute
                  ;;    dist_tick : ticks when the disturbance starts
                  ;; recovery_lag : number of ticks between the original disturbance and the respectiive recovery
              ;; disturbance_type : chooser for the type of disturbance: Simple,


;;;;;;;;;;;;;;;;;;;;;;;;;;;; MAIN PROCEDURES ;;;;;;;;;;;;;;;;;;;;;;;;;;;; MAIN PROCEDURES ;;;;;;;;;;;;;;;;;;;;;;;;;;;;
to setup
  clear-all

  if traffic_load = "morning_rush"
    [import-pcolors "tom tom Thess NL.jpg"]
  if traffic_load = "average"
    [import-pcolors "tom tom Thess NL - a.jpg"]
  if traffic_load = "evening_rush"
    [import-pcolors "tom tom Thess NL - e.jpg"]

  setup-patches
  setup-road-net
  setup-metrics
  setup-cars
  setup-hospital
  setup-patients
  reset-ticks
end

to go

  move-cars
  move-patients
  countroadcapacity

if extra_congestion > 0
      [extra-cong]

 if closed_road = true
      [close-road]

 if shuttle = true and any? patients = true
  [if shuttle_station = "en_route"
    [to-shuttle_en-route]
   if shuttle_station = "ahepa"
    [to-shuttle_ahepa]
   if shuttle_station = "station"
    [to-shuttle_station]]


  tick

if any? patients = false
  [stop]

end

;;;;;;;;; SETUP PROCEDURES ;;;;;;;;; SETUP PROCEDURES ;;;;;;;;; SETUP PROCEDURES ;;;;;;;;; SETUP PROCEDURES

to setup-patches
;;; 1) red region : heavy traffic load -> very high congestion ;;;;
  ask patches with [pcolor >= 11 and pcolor <= 17]
      [set traffic 1 + random-float 0.2 + random-float -0.2]

;;; 2) orange region: moderate traffic load -> moderate congestion ;;;;
  ask patches with [pcolor >= 21 and pcolor <= 27]
      [set traffic 2 + random-float 0.2 + random-float -0.2]

;;; 3) yellow region: small traffic load -> light congestion
  ask patches with [pcolor >= 41 and pcolor <= 47]
      [set traffic 3 + random-float 0.2 + random-float -0.2]

;;; grey region - sea ;;;;
  ask patches with [traffic = 0 ]
      [set pcolor 5]

;;; heatmap colors ;;;;
    ask patches with [ traffic >= 0.8 and traffic <= 1.2]
      [set pcolor scale-color red traffic 2 0]
    ask patches with [ traffic >= 1.8 and traffic <= 2.2]
      [set pcolor scale-color orange traffic 3 1]
    ask patches with [ traffic >= 2.8 and traffic <= 3.2]
      [set pcolor scale-color yellow traffic 4 2]

;;;reference traffic level ;;;
  ask patches with [pcolor != 5]
    [set ref_traffic 2.379
     set original_traffic traffic]

end


to setup-road-net
    ;;setting up of road network nodes
  create-roadnodes 60

  ask roadnodes
      [set shape "circle"
       set color red
       set size 0.5]

;;;;;  setting precise positions ;;;;
  ask roadnode 0
     [setxy -35 38
      create-rr-with roadnode 4]
   ask roadnode 1
     [setxy -25 37
      create-rr-with roadnode 3 ]
  ask roadnode 2
     [setxy -37 33
      create-rr-with roadnode 6]
  ask roadnode 3
     [setxy -21 34
      create-rr-with roadnode 4
      create-rr-with roadnode 5]
  ask roadnode 4
     [setxy -24 31
      create-rr-with roadnode 6]
  ask roadnode 5
     [setxy -12 28
      create-rr-with roadnode 9
      create-rr-with roadnode 7]
  ask roadnode 6
     [setxy -12 24
      create-rr-with roadnode 12]
  ask roadnode 7
     [setxy -8 26
      create-rr-with roadnode 6
      create-rr-with roadnode 9
      create-rr-with roadnode 10
      create-rr-with roadnode 11
      create-rr-with roadnode 14]
  ask roadnode 8
     [setxy -8 34
      create-rr-with roadnode 9]
  ask roadnode 9
     [setxy -8 30
      create-rr-with roadnode 10]
  ask roadnode 10
     [setxy -1 26
      create-rr-with roadnode 13]
  ask roadnode 11
     [setxy -7 21
      create-rr-with roadnode 12
      create-rr-with roadnode 19]
  ask roadnode 12
     [setxy -8 19
      create-rr-with roadnode 22]
  ask roadnode 13
     [setxy 4 22
      create-rr-with roadnode 14
      create-rr-with roadnode 16
      create-rr-with roadnode 17]
  ask roadnode 14
     [setxy 2 18
      create-rr-with roadnode 18]
  ask roadnode 15
     [setxy 16 28
      create-rr-with roadnode 16]
  ask roadnode 16
     [setxy 9 28]
  ask roadnode 17
     [setxy 11 18
      create-rr-with roadnode 25]
  ask roadnode 18
     [setxy 6 15
      create-rr-with roadnode 19]
  ask roadnode 19
     [setxy 4 12
      create-rr-with roadnode 21
      create-rr-with roadnode 22]
  ask roadnode 20
     [setxy 9 14
      create-rr-with roadnode 17
      create-rr-with roadnode 18
      create-rr-with roadnode 21
      create-rr-with roadnode 24]
  ask roadnode 21
     [setxy 8 9
      create-rr-with roadnode 22
      create-rr-with roadnode 23
      create-rr-with roadnode 29]
  ask roadnode 22
     [setxy 2 10
      create-rr-with roadnode 23]
  ask roadnode 23
     [setxy 8 6
      create-rr-with roadnode 38
      create-rr-with roadnode 39]
  ask roadnode 24
     [setxy 14 8
      create-rr-with roadnode 23
      create-rr-with roadnode 25
      create-rr-with roadnode 28]
  ask roadnode 25
     [setxy 18 9
      create-rr-with roadnode 27]
  ask roadnode 26
     [setxy 24 7
      create-rr-with roadnode 27]
  ask roadnode 27
     [setxy 21 4
      create-rr-with roadnode 30]
  ask roadnode 28
     [setxy 17 3
      create-rr-with roadnode 30
      create-rr-with roadnode 31]
  ask roadnode 29
     [setxy 11 3
      create-rr-with roadnode 31
      create-rr-with roadnode 32]
  ask roadnode 30
     [setxy 20 1
      create-rr-with roadnode 31
      create-rr-with roadnode 34]
  ask roadnode 31
     [setxy 17 0
      create-rr-with roadnode 32
      create-rr-with roadnode 35]
  ask roadnode 32
     [setxy 13 -3
      create-rr-with roadnode 35
      create-rr-with roadnode 36
      create-rr-with roadnode 37]
  ask roadnode 33
     [setxy 32 1]
  ask roadnode 34
     [setxy 26 -4
      create-rr-with roadnode 33
      create-rr-with roadnode 35
      create-rr-with roadnode 49]
  ask roadnode 35
     [setxy 17 -5
      create-rr-with roadnode 36
      create-rr-with roadnode 44]
  ask roadnode 36
     [setxy 17 -9
      create-rr-with roadnode 37
      create-rr-with roadnode 43]
  ask roadnode 37
     [setxy 12 -10
      create-rr-with roadnode 38
      create-rr-with roadnode 42]
  ask roadnode 38
     [setxy 9 -10
      create-rr-with roadnode 39
      create-rr-with roadnode 41]
  ask roadnode 39
     [setxy 7 -10
     create-rr-with roadnode 40]
  ask roadnode 40
     [setxy 6 -15
      create-rr-with roadnode 41
      create-rr-with roadnode 45]
  ask roadnode 41
     [setxy 8 -15
      create-rr-with roadnode 42
      create-rr-with roadnode 45]
  ask roadnode 42
     [setxy 12 -14
      create-rr-with roadnode 43
      create-rr-with roadnode 46]
  ask roadnode 43
     [setxy 17 -14
      create-rr-with roadnode 44
      create-rr-with roadnode 47]
  ask roadnode 44
     [setxy 20 -13
      create-rr-with roadnode 48]
  ask roadnode 45
     [setxy 7 -24
      create-rr-with roadnode 54
      create-rr-with roadnode 55
      create-rr-with roadnode 58]
  ask roadnode 46
     [setxy 13 -22
      create-rr-with roadnode 47
      create-rr-with roadnode 58]
  ask roadnode 47
     [setxy 18 -20
      create-rr-with roadnode 48
      create-rr-with roadnode 52]
  ask roadnode 48
     [setxy 22 -19
      create-rr-with roadnode 51]
  ask roadnode 49
     [setxy 39 -10
      create-rr-with roadnode 50]
  ask roadnode 50
     [setxy 32 -21
      create-rr-with roadnode 51]
  ask roadnode 51
     [setxy 23 -21
      create-rr-with roadnode 59]
  ask roadnode 52
     [setxy 18 -26
      create-rr-with roadnode 53
      create-rr-with roadnode 56
      create-rr-with roadnode 59]
  ask roadnode 53
     [setxy 12 -32
      create-rr-with roadnode 55
      create-rr-with roadnode 58]
  ask roadnode 54
     [setxy 6 -32]
  ask roadnode 55
     [setxy 9 -35]
  ask roadnode 56
     [setxy 20 -33
      create-rr-with roadnode 57]
  ask roadnode 57
     [setxy 24 -38]
  ask roadnode 58
     [setxy 9 -24]
  ask roadnode 59
     [setxy 24 -26]


;;;;;  setting up the network ;;;;

ask rrr
     [set color black
      set thickness 0.5]

end


to setup-metrics
  set roadcapacitylist []
  set patients_travel_time_list []
  set speed_rec_list []
  set patients_ETA []


end

to setup-cars
  ;;; set-up the private cars in the network ;;;
  ask n-of (0.50 * count patches with [traffic > 0]) patches with [traffic > 0]
    [sprout-cars 1
      [ask cars
         [set size 0.6
          set color black ]]]

  ask cars
    [foreach [cars] of turtles
      [ x ->  let closest_roadnode min-one-of roadnodes [distance myself]
              face closest_roadnode ]]
end

to setup-hospital

  ask patch  13 14 ; location of AHEPA hospital
    [sprout-hospital 1]

  ask hospital
   [set shape "x"
    set color blue
    set size 3
    set label "AHEPA"]

end

to setup-patients

;;; patients from Lagkada
  if Lagkada = true
    [ask n-of patient_density patches with [pxcor >= -17 and pxcor <= 3 and pycor >= 31 and pycor <= 40 and pcolor != 5]
    ;[ask patch -10 33
      [sprout-patients 1]
       ask patients
        [set shape "person"
         set color cyan
         set size 3
         set label "Lagkada"
         face roadnode 9] ]

 ;;; patients from Egnatia
  if Egnatia = true
    [ask n-of patient_density patches with [pxcor >= 11 and pxcor <= 40 and pycor <= -27 and pycor >= -40 and pcolor != 5]
    ;[ask patch 30 -31
      [sprout-patients 1]
       ask patients
        [set shape "person"
         set color cyan
         set size 3
         set label "Egnatia"
         face roadnode 52] ]

end

;;;;;;;;; PROCEDURES ;;;;;;;;; PROCEDURES;;;;;;;;; PROCEDURES ;;;;;;;;; PROCEDURES ;;;;;;;;;

to move-cars
  ;;; movement of cars: speed, direction, and interactions ;;;
  ask cars with [label = ""]
    [if can-move? 1 and [pcolor] of patch-ahead 1 != 5
      [set speed traffic
        forward traffic ]

     if can-move? 1 and [pcolor] of patch-ahead 1 = 5
      [set speed traffic
       forward (-1 * traffic) ]]


  ask cars
    [foreach [cars] of turtles
      [ x ->  let closest_roadnode min-one-of neighbors [distance myself]
              face closest_roadnode ]]

 ask roadnodes
   [ask n-of (0.20 * count cars in-radius 1) cars in-radius 1
      [die]]

  ask cars with [label = ""]
      [if [pcolor] of patch-here = 5
          [die]]

 if count cars < 1757
 [ask n-of (1757 - count cars) patches with [traffic > 0]
        [sprout-cars 1
          [ask cars
           [set size 0.6
            set color black ]]]]

end

to move-patients

  ask patients with [label = "Lagkada"]
  [ifelse xcor != -8 and ycor > 30
    [face roadnode 9
      if can-move? 1 and [pcolor] of patch-ahead 1 != 5
        [set speed traffic
         forward traffic ]]
    [face patch 13 14 ; AHEPA hospital
     if can-move? 1 and [pcolor] of patch-ahead 1 != 5
        [set speed traffic
         forward traffic ]
     if can-move? 1 and [pcolor] of patch-ahead 1 = 5
        [set speed traffic
         set heading 45
         forward traffic ]] ]

 ask patients with [label = "Egnatia"]
  [ifelse ycor < -26
    [face roadnode 52
      if can-move? 1 and [pcolor] of patch-ahead 1 != 5
        [set speed traffic
         forward traffic ]]
    [face patch 13 14 ; AHEPA hospital
     if can-move? 1 and [pcolor] of patch-ahead 1 != 5
        [set speed traffic
         forward traffic ]
     if can-move? 1 and [pcolor] of patch-ahead 1 = 5
        [set speed traffic
         set heading -45
         forward traffic ]] ]

  ask patients
   [if any? hospital in-radius 1
      [set patients_arrival ticks + 1
       set patients_travel_time_list lput (patients_arrival * 1.92)  patients_travel_time_list ; 1.92 average time ratio calculated from average traffic conditions
       set patients_travel_time mean (patients_travel_time_list)
       die]]

  if any? patients = true
    [set patients_speed mean [speed] of patients * 21.3]; 21.3 average speed of network

  if empty? patients_travel_time_list = false
    [set patients_travel_time mean (patients_travel_time_list) ]

end

;;;;;; PERFORMANCE ASSESSMENT PROCEDURES ;;;;;;; PERFORMANCE ASSESSMENT PROCEDURES ;;;;;;;

to countroadcapacity


  ask patches with [pcolor != 5]
    [set stress (mean [traffic] of patches with [pcolor != 5] - ref_traffic) / ref_traffic * 100 ]

  ask cars
    [set throughput (count cars with [speed > 0] / count cars)]

  ask roadnodes
    [let dormant_links sum [count patches with [pcolor >= 41  and pcolor <= 48] in-radius 2] of roadnodes
     let active_links sum [count patches with [pcolor != 5] in-radius 2] of roadnodes
     set redundancy 1 - (dormant_links / active_links) / (360 / 773)] ;;reference value from average traffic scenario


  ask turtles with [speed > 0]
    [set speed_rec_list lput [speed] of self speed_rec_list
     if empty? speed_rec_list = false
      [set max_speed max [speed_rec_list] of self
       let max_pln_sp ln (max_speed)
       set max_entropy sum [max_pln_sp] of turtles]]

  ask turtles with [speed > 0 and max_entropy > 0]
    [let pln_sp ln (speed)
     set entropy (sum [pln_sp] of turtles) / max_entropy ]

  if any? patients with [speed > 0]
   [ask patients
      [set patients_ETA lput ((patients_speed - 46.72)/ 46.72) patients_ETA ; 46.72 cars' average speed after 100 runs in average traffic conditions
       set satisfaction (mean patients_ETA) ]]


 ask roadnodes
      [set teleCom ((count rrr)/ 94 - 1) * 100] ; 94 is the total number of links at the beggining of the simulation

 ask turtles with [speed > 0]
  [if empty? speed_rec_list = false
    [let avg_speed mean [speed_rec_list] of self
     set energy mean [(speed / avg_speed) - 1] of turtles]]

end


;;;;;; DISTURBANCE PROCEDURES ;;;;;; DISTURBANCE PROCEDURES ;;;;;;

to extra-cong

  ask hospital
    [ask patches with [pcolor >= 11 and pcolor <= 17] in-radius cong_area
      [set pcolor 15 - (4 * extra_congestion)
       set traffic (original_traffic - extra_congestion)]

     ask patches with [pcolor >= 21 and pcolor <= 27] in-radius cong_area
      [set pcolor 25 - (4 * extra_congestion)
       set traffic (original_traffic - extra_congestion)]

     ask patches with [pcolor >= 41 and pcolor <= 47] in-radius cong_area
      [set pcolor 45 - (4 * extra_congestion)
       set traffic (original_traffic - extra_congestion)]]

end

to close-road

  if Lagkada = true
    [ask (patch-set patch 11 19 patch 11 18 patch 10 18 patch 10 17 patch 10 16 patch 9 15 patch 9 14)
      [set pcolor 5
       set traffic 0
       ask patches in-radius 3 with [pcolor != 5]
        [set traffic (original_traffic / 2)
         set pcolor 14]]]

  if Egnatia = true
    [ask (patch-set patch 11 11 patch 12 10 patch 13 9 patch 14 8 patch 15 7)
      [set pcolor 5
       set traffic 0
       ask patches in-radius 3 with [pcolor != 5]
        [set traffic (original_traffic / 2)
         set pcolor 14]]]

end


;;;;;; RECOVERY PROCEDURES ;;;;;; RECOVERY PROCEDURES ;;;;;;

to to-shuttle_en-route ; shuttle on route around the city

  if Lagkada = true and any? patients = true and any? patients with [label = "SL"] = false and any? cars with [label = "SL"] = false
     [ask one-of patches with [pxcor >= -17 and pxcor < 24 and pycor >= 31]
       [sprout-cars 1
        [set color green
         set label "SL"
         set size 3
         face min-one-of patients [distance self]] ]]

     ask cars with [label = "SL"]
       [ifelse any? patients in-radius 3 = false
            [face min-one-of patients [distance myself]
             forward 1]
            [ask patients in-radius 3
              [set label "SL"
               set color green]
               die] ]

     ask patients with [label = "SL"]
       [if [pcolor] of patch-here = 5 or any? neighbors with [pcolor = 5]
             [set color white
              set heading 0
              forward (2)]

        if [pcolor] of patch-here != 5
         [set color green
          face patch 13 14
          forward (1 + (traffic / 2))]

         if any? hospital in-radius 3
           [set patients_arrival ticks + 1
            set patients_travel_time_list lput (patients_arrival * 1.92)  patients_travel_time_list ; 1.92 average time ratio calculated from average traffic conditions
            set patients_travel_time mean (patients_travel_time_list)
            die]]


 ;;; check and fix this procedure based on the above ;;;
  if Egnatia = true and any? patients = true and any? patients with [label = "SE"] = false and any? cars with [label = "SE"] = false
     [ask one-of patches with [pxcor >= 11 and pycor <= -27]
      [sprout-cars 1
        [set color green
         set label "SE"
         set size 3
         face min-one-of patients [distance self]] ]]

     ask cars with [label = "SE"]
       [ifelse any? patients in-radius 3 = false
            [face min-one-of patients [distance myself]
             forward 1]
            [ask patients in-radius 3
              [set label "SΕ"
               set color green]
               die] ]

     ask patients with [label = "SE"]
       [if [pcolor] of patch-here = 5 or any? neighbors with [pcolor = 5]
             [set color white
              set heading 0
              forward (2)]

       if [pcolor] of patch-here != 5
        [face patch 13 14
         forward (1 + (traffic / 2))]

         if any? hospital in-radius 3
           [set patients_arrival ticks + 1
            set patients_travel_time_list lput (patients_arrival * 1.92)  patients_travel_time_list ; 1.92 average time ratio calculated from average traffic conditions
            set patients_travel_time mean (patients_travel_time_list)
            die]]

end

to to-shuttle_ahepa
    if Lagkada = true and any? patients = true and any? patients with [label = "SL"] = false and any? cars with [label = "SL"] = false
     [ask patch 13 14
       [sprout-cars 1
        [set color green
         set label "SL"
         set size 3
         face min-one-of patients [distance self]] ]]

     ask cars with  [label = "SL"]
       [ifelse any? patients in-radius 3 = false
            [face min-one-of patients [distance myself]
             forward 1]
            [ask patients in-radius 3
              [set label "SL"
               set color green]
               die] ]

     ask patients with [label = "SL"]
       [if [pcolor] of patch-here = 5 or any? neighbors with [pcolor = 5]
             [set color white
              set heading 0
              forward (2)]

        if [pcolor] of patch-here != 5
         [set color green
          face patch 13 14
          forward (1 + (traffic / 2))]

         if any? hospital in-radius 3
           [set patients_arrival ticks + 1
            set patients_travel_time_list lput (patients_arrival * 1.92)  patients_travel_time_list ; 1.92 average time ratio calculated from average traffic conditions
            set patients_travel_time mean (patients_travel_time_list)
            die]]

 ;;; check and fix this procedure based on the above ;;;
  if Egnatia = true and any? patients = true and any? patients with [label = "SE"] = false and any? cars with [label = "SE"] = false
     [ask patch 13 14
      [sprout-cars 1
        [set color green
         set label "SE"
         set size 3
         face min-one-of patients [distance self]] ]]

    ask cars with [label = "SE"]
       [ifelse any? patients in-radius 3 = false
            [face min-one-of patients [distance myself]
             forward 1]
            [ask patients in-radius 3
              [set label "SΕ"
               set color green]
               die] ]

     ask patients with [label = "SE"]
         [if [pcolor] of patch-here = 5 or any? neighbors with [pcolor = 5]
             [set color white
              set heading 0
              forward (2)]

       if [pcolor] of patch-here != 5
        [face patch 13 14
         forward (1 + (traffic / 2))]

         if any? hospital in-radius 3
           [set patients_arrival ticks + 1
            set patients_travel_time_list lput (patients_arrival * 1.92)  patients_travel_time_list ; 1.92 average time ratio calculated from average traffic conditions
            set patients_travel_time mean (patients_travel_time_list)
            die]]

end

to to-shuttle_station

 if Lagkada = true and any? patients = true and any? patients with [label = "SL"] = false and any? cars with [label = "SL"] = false
     [ask patch 19 18
       [set pcolor blue
        sprout-cars 1
         [set color green
          set label "SL"
          set size 3
          face min-one-of patients [distance self]] ]]

     ask cars with  [label = "SL"]
       [ifelse any? patients in-radius 3 = false
            [face min-one-of patients [distance myself]
             forward (1 + (traffic / 2))]
            [ask patients in-radius 3
              [set label "SL"
               set color green]
               die] ]

  ask patients with [label = "SL"]
        [if pycor > 14 and not any? neighbors with [ pcolor = 5 ] and closed_road = false;in-radius (2 * traffic)
          [let check-patches patches with [pycor <= [pycor] of myself and pxcor > [pxcor] of myself and pcolor != 5] in-radius (2 * traffic)
           let target-patch one-of check-patches with [traffic = max [traffic] of check-patches]
           face target-patch
           if [pcolor] of patch-ahead (2 * traffic) != 5 and [pycor] of patch-ahead (2 * traffic) < [pycor] of self
             [forward (2 * traffic) ]]
         if any? neighbors with [pcolor = 5] and closed_road = false
          [face one-of neighbors with [ traffic = max [traffic] of neighbors]
           forward (2 * traffic) ]

         if pycor <= 14 or pxcor >= 6
          [face patch 13 14
           forward (2 * traffic)]
         if any? hospital in-radius 3
           [set patients_arrival ticks + 1
            set patients_travel_time_list lput (patients_arrival * 1.92)  patients_travel_time_list ; 1.92 average time ratio calculated from average traffic conditions
            set patients_travel_time mean (patients_travel_time_list)
              die]]

  if closed_road = true
    [ask patients with [label = "SL"]
       [if pycor > 14 and not any? neighbors with [ pcolor = 5 ]
          [let check-patches patches with [pycor < [pycor] of myself and pxcor > [pxcor] of myself and pcolor != 5] in-radius (2 * traffic)
           let target-patch one-of check-patches with [traffic = max [traffic] of check-patches]
           face target-patch
           if [pcolor] of patch-ahead (2 * traffic) != 5 and [pycor] of patch-ahead (2 * traffic) < [pycor] of self
             [forward (2 * traffic) ]]
        if [pcolor] of patch-ahead (2 * traffic) = 5 or any? neighbors with [pcolor = 5] or [pcolor] of patch-here = 5
          [face one-of neighbors with [traffic > mean [traffic] of neighbors]
           forward (2 * traffic)]]]


  if Egnatia = true and any? patients = true and any? patients with [label = "SE"] = false and any? cars with [label = "SE"] = false
     [ask patch 19 18
       [set pcolor blue
        sprout-cars 1
         [set color green
          set label "SE"
          set size 3
          face min-one-of patients [distance self]] ]]

     ask cars with  [label = "SE"]
       [ifelse any? patients in-radius 3 = false
            [face min-one-of patients [distance myself]
             forward (1 + (traffic / 2))]
            [ask patients in-radius 3
              [set label "SE"
               set color green]
               die] ]

  ask patients with [label = "SE"]
        [if pycor < 5 and not any? neighbors with [pcolor = 5] and closed_road = false;in-radius (2 * traffic)
          [let check-patches patches with [pycor > [pycor] of myself and pcolor != 5] in-radius (2 * traffic)
           let target-patch one-of check-patches with [traffic = max [traffic] of check-patches]
           face target-patch
           if [pcolor] of patch-ahead (2 * traffic) != 5 and [pycor] of patch-ahead (2 * traffic) > [pycor] of self
             [forward (2 * traffic) ] ]
         if any? neighbors with [pcolor = 5 ]
          [face one-of neighbors with [pcolor != 5] ;traffic = min [traffic] of neighbors and
           forward (1) ]
         if pycor >= 5
          [face patch 13 14
           forward (2 * traffic)]
         if any? hospital in-radius 3
           [set patients_arrival ticks + 1
            set patients_travel_time_list lput (patients_arrival * 1.92)  patients_travel_time_list ; 1.92 average time ratio calculated from average traffic conditions
            set patients_travel_time mean (patients_travel_time_list)
            die]]

   if closed_road = true
    [ask patients with [label = "SE"]
       [if pycor < 5 and not any? neighbors with [ pcolor = 5 ]
          [let check-patches patches with [pycor < [pycor] of myself and pxcor > [pxcor] of myself and pcolor != 5] in-radius (2 * traffic)
           let target-patch one-of check-patches with [traffic = max [traffic] of check-patches]
           face target-patch
           if [pcolor] of patch-ahead (2 * traffic) != 5 and [pycor] of patch-ahead (2 * traffic) < [pycor] of self
             [forward (2 * traffic) ]]
        if [pcolor] of patch-ahead (2 * traffic) = 5 or any? neighbors with [pcolor = 5] or [pcolor] of patch-here = 5
          [face one-of neighbors with [traffic > mean [traffic] of neighbors]
           forward (2 * traffic)]]]

end

to to-transfer

    if Lagkada = true and any? patients = true and any? patients with [label = "TL"] = false
      [ask patients
        [set color green
         set label "TL"
         face patch 13 14]]

      ask patients with [label = "TL"]
       [face patch 13 14
        move-to max-one-of neighbors [[traffic] of patches]
        forward traffic

        if any? hospital in-radius 1
           [set patients_arrival ticks + 1
            set patients_travel_time_list lput (patients_arrival * speed / 70)  patients_travel_time_list
            set patients_travel_time mean (patients_travel_time_list) * 60
            die]]

end
@#$#@#$#@
GRAPHICS-WINDOW
220
10
633
424
-1
-1
5.0
1
10
1
1
1
0
0
0
1
-40
40
-40
40
0
0
1
ticks
30.0

BUTTON
5
10
68
43
setup
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
76
10
131
43
go
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
139
11
197
44
go once
go
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

MONITOR
642
36
753
77
Throughput M
throughput
3
1
10

SLIDER
7
189
119
222
extra_congestion
extra_congestion
0
1
0.0
0.1
1
NIL
HORIZONTAL

SWITCH
8
226
116
259
closed_road
closed_road
0
1
-1000

PLOT
765
15
1158
256
Total System Performance Levels
ticks
change %
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"efficiency" 1.0 0 -13345367 true "" "plot ((1 - throughput) + stress)"
"redundancy" 1.0 0 -7500403 true "" "plot redundancy + entropy"
"energy" 1.0 0 -2674135 true "" "plot energy"
"satisfaction" 1.0 0 -13840069 true "" "plot satisfaction"

MONITOR
5
348
99
385
Number of cars
count cars
3
1
9

MONITOR
6
388
99
425
Speed of cars (km/h)
mean [speed] of cars * 21.3
3
1
9

CHOOSER
6
68
98
113
traffic_load
traffic_load
"morning_rush" "average" "evening_rush"
0

MONITOR
102
348
212
385
Speed of patients (km/h)
patients_speed
3
1
9

MONITOR
103
388
213
425
Patients travel time (min)
mean (patients_travel_time_list)
3
1
9

SLIDER
101
69
212
102
patient_density
patient_density
0
10
1.0
1
1
NIL
HORIZONTAL

SWITCH
8
133
98
166
Lagkada
Lagkada
0
1
-1000

SWITCH
100
133
190
166
Egnatia
Egnatia
1
1
-1000

TEXTBOX
10
115
160
133
Areas of origin
11
0.0
1

TEXTBOX
7
329
157
347
Flow in road network
11
0.0
1

TEXTBOX
7
51
157
69
Traffic parameters
11
0.0
1

MONITOR
642
81
753
122
Efficiency S (%)
stress
3
1
10

TEXTBOX
646
12
796
30
AntifragiCity KPIs
11
0.0
1

MONITOR
642
127
754
168
Redundancy R (%)
redundancy
3
1
10

MONITOR
643
172
754
213
Entropy C
entropy
3
1
10

MONITOR
644
217
754
258
Satisfaction Q (%)
satisfaction
3
1
10

MONITOR
645
261
754
302
Energy (%)
energy
3
1
10

TEXTBOX
12
171
162
189
Disruption
11
0.0
1

SLIDER
122
189
214
222
cong_area
cong_area
0
20
3.0
1
1
NIL
HORIZONTAL

TEXTBOX
11
266
115
284
Response
11
0.0
1

SWITCH
8
286
104
319
shuttle
shuttle
0
1
-1000

CHOOSER
108
274
215
319
shuttle_station
shuttle_station
"en_route" "ahepa" "station"
1

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.4.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="EGNATIA TEST shuttle station" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="100"/>
    <metric>mean [speed] of cars * 21.3</metric>
    <metric>patients_speed</metric>
    <metric>patients_travel_time</metric>
    <metric>throughput</metric>
    <metric>stress</metric>
    <metric>redundancy</metric>
    <metric>entropy</metric>
    <metric>satisfaction</metric>
    <metric>energy</metric>
    <metric>teleCom</metric>
    <enumeratedValueSet variable="Egnatia">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Lagkada">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cong_area">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="patient_density">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="closed_road">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extra_congestion">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="traffic_load">
      <value value="&quot;morning_rush&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="shuttle">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="shuttle_station">
      <value value="&quot;station&quot;"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="SH-EnR_Lagkada_AVRG" repetitions="10" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="100"/>
    <metric>mean [speed] of cars * 21.3</metric>
    <metric>patients_speed</metric>
    <metric>patients_travel_time</metric>
    <metric>throughput</metric>
    <metric>stress</metric>
    <metric>redundancy</metric>
    <metric>entropy</metric>
    <metric>satisfaction</metric>
    <metric>energy</metric>
    <metric>teleCom</metric>
    <enumeratedValueSet variable="Egnatia">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="shuttle_station">
      <value value="&quot;en_route&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Lagkada">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="patient_density">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cong_area">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="closed_road">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extra_congestion">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="traffic_load">
      <value value="&quot;average&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="shuttle">
      <value value="true"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="SH-EnR_Lagkada_MR" repetitions="10" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="100"/>
    <metric>mean [speed] of cars * 21.3</metric>
    <metric>patients_speed</metric>
    <metric>patients_travel_time</metric>
    <metric>throughput</metric>
    <metric>stress</metric>
    <metric>redundancy</metric>
    <metric>entropy</metric>
    <metric>satisfaction</metric>
    <metric>energy</metric>
    <metric>teleCom</metric>
    <enumeratedValueSet variable="Egnatia">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="shuttle_station">
      <value value="&quot;en_route&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Lagkada">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="patient_density">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cong_area">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="closed_road">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extra_congestion">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="traffic_load">
      <value value="&quot;morning_rush&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="shuttle">
      <value value="true"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="SH-EnR_Lagkada_ER" repetitions="10" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="100"/>
    <metric>mean [speed] of cars * 21.3</metric>
    <metric>patients_speed</metric>
    <metric>patients_travel_time</metric>
    <metric>throughput</metric>
    <metric>stress</metric>
    <metric>redundancy</metric>
    <metric>entropy</metric>
    <metric>satisfaction</metric>
    <metric>energy</metric>
    <metric>teleCom</metric>
    <enumeratedValueSet variable="Egnatia">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="shuttle_station">
      <value value="&quot;en_route&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Lagkada">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="patient_density">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cong_area">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="closed_road">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extra_congestion">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="traffic_load">
      <value value="&quot;evening_rush&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="shuttle">
      <value value="true"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="SH-Ahp_Lagkada_AVRG" repetitions="10" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="100"/>
    <metric>mean [speed] of cars * 21.3</metric>
    <metric>patients_speed</metric>
    <metric>patients_travel_time</metric>
    <metric>throughput</metric>
    <metric>stress</metric>
    <metric>redundancy</metric>
    <metric>entropy</metric>
    <metric>satisfaction</metric>
    <metric>energy</metric>
    <metric>teleCom</metric>
    <enumeratedValueSet variable="Egnatia">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="shuttle_station">
      <value value="&quot;ahepa&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Lagkada">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="patient_density">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cong_area">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="closed_road">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extra_congestion">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="traffic_load">
      <value value="&quot;average&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="shuttle">
      <value value="true"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="SH-Ahp_Lagkada_MR" repetitions="10" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="100"/>
    <metric>mean [speed] of cars * 21.3</metric>
    <metric>patients_speed</metric>
    <metric>patients_travel_time</metric>
    <metric>throughput</metric>
    <metric>stress</metric>
    <metric>redundancy</metric>
    <metric>entropy</metric>
    <metric>satisfaction</metric>
    <metric>energy</metric>
    <metric>teleCom</metric>
    <enumeratedValueSet variable="Egnatia">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="shuttle_station">
      <value value="&quot;ahepa&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Lagkada">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="patient_density">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cong_area">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="closed_road">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extra_congestion">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="traffic_load">
      <value value="&quot;morning_rush&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="shuttle">
      <value value="true"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="SH-Ahp_Lagkada_ER" repetitions="10" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="100"/>
    <metric>mean [speed] of cars * 21.3</metric>
    <metric>patients_speed</metric>
    <metric>patients_travel_time</metric>
    <metric>throughput</metric>
    <metric>stress</metric>
    <metric>redundancy</metric>
    <metric>entropy</metric>
    <metric>satisfaction</metric>
    <metric>energy</metric>
    <metric>teleCom</metric>
    <enumeratedValueSet variable="Egnatia">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="shuttle_station">
      <value value="&quot;ahepa&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Lagkada">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="patient_density">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cong_area">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="closed_road">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extra_congestion">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="traffic_load">
      <value value="&quot;evening_rush&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="shuttle">
      <value value="true"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="SH-St_Lagkada_AVRG" repetitions="10" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="100"/>
    <metric>mean [speed] of cars * 21.3</metric>
    <metric>patients_speed</metric>
    <metric>patients_travel_time</metric>
    <metric>throughput</metric>
    <metric>stress</metric>
    <metric>redundancy</metric>
    <metric>entropy</metric>
    <metric>satisfaction</metric>
    <metric>energy</metric>
    <metric>teleCom</metric>
    <enumeratedValueSet variable="Egnatia">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="shuttle_station">
      <value value="&quot;station&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Lagkada">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="patient_density">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cong_area">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="closed_road">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extra_congestion">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="traffic_load">
      <value value="&quot;average&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="shuttle">
      <value value="true"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="SH-St_Lagkada_MR" repetitions="10" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="100"/>
    <metric>mean [speed] of cars * 21.3</metric>
    <metric>patients_speed</metric>
    <metric>patients_travel_time</metric>
    <metric>throughput</metric>
    <metric>stress</metric>
    <metric>redundancy</metric>
    <metric>entropy</metric>
    <metric>satisfaction</metric>
    <metric>energy</metric>
    <metric>teleCom</metric>
    <enumeratedValueSet variable="Egnatia">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="shuttle_station">
      <value value="&quot;station&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Lagkada">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="patient_density">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cong_area">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="closed_road">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extra_congestion">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="traffic_load">
      <value value="&quot;morning_rush&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="shuttle">
      <value value="true"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="SH-St_Lagkada_ER" repetitions="10" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="100"/>
    <metric>mean [speed] of cars * 21.3</metric>
    <metric>patients_speed</metric>
    <metric>patients_travel_time</metric>
    <metric>throughput</metric>
    <metric>stress</metric>
    <metric>redundancy</metric>
    <metric>entropy</metric>
    <metric>satisfaction</metric>
    <metric>energy</metric>
    <metric>teleCom</metric>
    <enumeratedValueSet variable="Egnatia">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="shuttle_station">
      <value value="&quot;station&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Lagkada">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="patient_density">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cong_area">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="closed_road">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extra_congestion">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="traffic_load">
      <value value="&quot;evening_rush&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="shuttle">
      <value value="true"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="SH-EnR_Egnatia_AVRG" repetitions="10" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="100"/>
    <metric>mean [speed] of cars * 21.3</metric>
    <metric>patients_speed</metric>
    <metric>patients_travel_time</metric>
    <metric>throughput</metric>
    <metric>stress</metric>
    <metric>redundancy</metric>
    <metric>entropy</metric>
    <metric>satisfaction</metric>
    <metric>energy</metric>
    <metric>teleCom</metric>
    <enumeratedValueSet variable="Egnatia">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="shuttle_station">
      <value value="&quot;en_route&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Lagkada">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="patient_density">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cong_area">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="closed_road">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extra_congestion">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="traffic_load">
      <value value="&quot;average&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="shuttle">
      <value value="true"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="SH-EnR_Egnatia_MR" repetitions="10" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="100"/>
    <metric>mean [speed] of cars * 21.3</metric>
    <metric>patients_speed</metric>
    <metric>patients_travel_time</metric>
    <metric>throughput</metric>
    <metric>stress</metric>
    <metric>redundancy</metric>
    <metric>entropy</metric>
    <metric>satisfaction</metric>
    <metric>energy</metric>
    <metric>teleCom</metric>
    <enumeratedValueSet variable="Egnatia">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="shuttle_station">
      <value value="&quot;en_route&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Lagkada">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="patient_density">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cong_area">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="closed_road">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extra_congestion">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="traffic_load">
      <value value="&quot;morning_rush&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="shuttle">
      <value value="true"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="SH-Ahp_Egnatia_AVRG" repetitions="10" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="100"/>
    <metric>mean [speed] of cars * 21.3</metric>
    <metric>patients_speed</metric>
    <metric>patients_travel_time</metric>
    <metric>throughput</metric>
    <metric>stress</metric>
    <metric>redundancy</metric>
    <metric>entropy</metric>
    <metric>satisfaction</metric>
    <metric>energy</metric>
    <metric>teleCom</metric>
    <enumeratedValueSet variable="Egnatia">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="shuttle_station">
      <value value="&quot;ahepa&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Lagkada">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="patient_density">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cong_area">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="closed_road">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extra_congestion">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="traffic_load">
      <value value="&quot;average&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="shuttle">
      <value value="true"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="SH-Ahp_Egnatia_MR" repetitions="10" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="100"/>
    <metric>mean [speed] of cars * 21.3</metric>
    <metric>patients_speed</metric>
    <metric>patients_travel_time</metric>
    <metric>throughput</metric>
    <metric>stress</metric>
    <metric>redundancy</metric>
    <metric>entropy</metric>
    <metric>satisfaction</metric>
    <metric>energy</metric>
    <metric>teleCom</metric>
    <enumeratedValueSet variable="Egnatia">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="shuttle_station">
      <value value="&quot;ahepa&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Lagkada">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="patient_density">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cong_area">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="closed_road">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extra_congestion">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="traffic_load">
      <value value="&quot;morning_rush&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="shuttle">
      <value value="true"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="SH-St_Egnatia_AVRG" repetitions="10" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="100"/>
    <metric>mean [speed] of cars * 21.3</metric>
    <metric>patients_speed</metric>
    <metric>patients_travel_time</metric>
    <metric>throughput</metric>
    <metric>stress</metric>
    <metric>redundancy</metric>
    <metric>entropy</metric>
    <metric>satisfaction</metric>
    <metric>energy</metric>
    <metric>teleCom</metric>
    <enumeratedValueSet variable="Egnatia">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="shuttle_station">
      <value value="&quot;station&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Lagkada">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="patient_density">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cong_area">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="closed_road">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extra_congestion">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="traffic_load">
      <value value="&quot;average&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="shuttle">
      <value value="true"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="SH-St_Egnatia_MR" repetitions="10" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="100"/>
    <metric>mean [speed] of cars * 21.3</metric>
    <metric>patients_speed</metric>
    <metric>patients_travel_time</metric>
    <metric>throughput</metric>
    <metric>stress</metric>
    <metric>redundancy</metric>
    <metric>entropy</metric>
    <metric>satisfaction</metric>
    <metric>energy</metric>
    <metric>teleCom</metric>
    <enumeratedValueSet variable="Egnatia">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="shuttle_station">
      <value value="&quot;station&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Lagkada">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="patient_density">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cong_area">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="closed_road">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extra_congestion">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="traffic_load">
      <value value="&quot;morning_rush&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="shuttle">
      <value value="true"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Dis-Cong Intnesity SH-EnR_Lagkada_AVRG" repetitions="10" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="100"/>
    <metric>mean [speed] of cars * 21.3</metric>
    <metric>patients_speed</metric>
    <metric>patients_travel_time</metric>
    <metric>throughput</metric>
    <metric>stress</metric>
    <metric>redundancy</metric>
    <metric>entropy</metric>
    <metric>satisfaction</metric>
    <metric>energy</metric>
    <metric>teleCom</metric>
    <enumeratedValueSet variable="Egnatia">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="shuttle_station">
      <value value="&quot;en_route&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Lagkada">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="patient_density">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cong_area">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="closed_road">
      <value value="false"/>
    </enumeratedValueSet>
    <steppedValueSet variable="extra_congestion" first="0" step="0.1" last="1"/>
    <enumeratedValueSet variable="traffic_load">
      <value value="&quot;average&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="shuttle">
      <value value="true"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Dis-Cong Intnesity SH-EnR_Lagkada_MR" repetitions="10" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="100"/>
    <metric>mean [speed] of cars * 21.3</metric>
    <metric>patients_speed</metric>
    <metric>patients_travel_time</metric>
    <metric>throughput</metric>
    <metric>stress</metric>
    <metric>redundancy</metric>
    <metric>entropy</metric>
    <metric>satisfaction</metric>
    <metric>energy</metric>
    <metric>teleCom</metric>
    <enumeratedValueSet variable="Egnatia">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="shuttle_station">
      <value value="&quot;en_route&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Lagkada">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="patient_density">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cong_area">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="closed_road">
      <value value="false"/>
    </enumeratedValueSet>
    <steppedValueSet variable="extra_congestion" first="0" step="0.1" last="1"/>
    <enumeratedValueSet variable="traffic_load">
      <value value="&quot;morning_rush&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="shuttle">
      <value value="true"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Dis-Cong Intnesity SH-Ahp_Lagkada_AVRG" repetitions="10" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="100"/>
    <metric>mean [speed] of cars * 21.3</metric>
    <metric>patients_speed</metric>
    <metric>patients_travel_time</metric>
    <metric>throughput</metric>
    <metric>stress</metric>
    <metric>redundancy</metric>
    <metric>entropy</metric>
    <metric>satisfaction</metric>
    <metric>energy</metric>
    <metric>teleCom</metric>
    <enumeratedValueSet variable="Egnatia">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="shuttle_station">
      <value value="&quot;ahepa&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Lagkada">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="patient_density">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cong_area">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="closed_road">
      <value value="false"/>
    </enumeratedValueSet>
    <steppedValueSet variable="extra_congestion" first="0" step="0.1" last="1"/>
    <enumeratedValueSet variable="traffic_load">
      <value value="&quot;average&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="shuttle">
      <value value="true"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Dis-Cong Intnesity SH-Ahp_Lagkada_MR" repetitions="10" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="100"/>
    <metric>mean [speed] of cars * 21.3</metric>
    <metric>patients_speed</metric>
    <metric>patients_travel_time</metric>
    <metric>throughput</metric>
    <metric>stress</metric>
    <metric>redundancy</metric>
    <metric>entropy</metric>
    <metric>satisfaction</metric>
    <metric>energy</metric>
    <metric>teleCom</metric>
    <enumeratedValueSet variable="Egnatia">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="shuttle_station">
      <value value="&quot;ahepa&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Lagkada">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="patient_density">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cong_area">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="closed_road">
      <value value="false"/>
    </enumeratedValueSet>
    <steppedValueSet variable="extra_congestion" first="0" step="0.1" last="1"/>
    <enumeratedValueSet variable="traffic_load">
      <value value="&quot;morning_rush&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="shuttle">
      <value value="true"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Dis-Cong Intnesity SH-St_Lagkada_AVRG" repetitions="10" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="100"/>
    <metric>mean [speed] of cars * 21.3</metric>
    <metric>patients_speed</metric>
    <metric>patients_travel_time</metric>
    <metric>throughput</metric>
    <metric>stress</metric>
    <metric>redundancy</metric>
    <metric>entropy</metric>
    <metric>satisfaction</metric>
    <metric>energy</metric>
    <metric>teleCom</metric>
    <enumeratedValueSet variable="Egnatia">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="shuttle_station">
      <value value="&quot;station&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Lagkada">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="patient_density">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cong_area">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="closed_road">
      <value value="false"/>
    </enumeratedValueSet>
    <steppedValueSet variable="extra_congestion" first="0" step="0.1" last="1"/>
    <enumeratedValueSet variable="traffic_load">
      <value value="&quot;average&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="shuttle">
      <value value="true"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Dis-Cong Intnesity SH-St_Lagkada_MR" repetitions="10" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="100"/>
    <metric>mean [speed] of cars * 21.3</metric>
    <metric>patients_speed</metric>
    <metric>patients_travel_time</metric>
    <metric>throughput</metric>
    <metric>stress</metric>
    <metric>redundancy</metric>
    <metric>entropy</metric>
    <metric>satisfaction</metric>
    <metric>energy</metric>
    <metric>teleCom</metric>
    <enumeratedValueSet variable="Egnatia">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="shuttle_station">
      <value value="&quot;station&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Lagkada">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="patient_density">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cong_area">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="closed_road">
      <value value="false"/>
    </enumeratedValueSet>
    <steppedValueSet variable="extra_congestion" first="0" step="0.1" last="1"/>
    <enumeratedValueSet variable="traffic_load">
      <value value="&quot;morning_rush&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="shuttle">
      <value value="true"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Dis-Cong Area SH-EnR_Lagkada_AVRG" repetitions="10" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="100"/>
    <metric>mean [speed] of cars * 21.3</metric>
    <metric>patients_speed</metric>
    <metric>patients_travel_time</metric>
    <metric>throughput</metric>
    <metric>stress</metric>
    <metric>redundancy</metric>
    <metric>entropy</metric>
    <metric>satisfaction</metric>
    <metric>energy</metric>
    <metric>teleCom</metric>
    <enumeratedValueSet variable="Egnatia">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="shuttle_station">
      <value value="&quot;en_route&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Lagkada">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="patient_density">
      <value value="1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="cong_area" first="0" step="2" last="20"/>
    <enumeratedValueSet variable="closed_road">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extra_congestion">
      <value value="0.4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="traffic_load">
      <value value="&quot;average&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="shuttle">
      <value value="true"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Dis-Cong Area SH-EnR_Lagkada_MR" repetitions="10" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="100"/>
    <metric>mean [speed] of cars * 21.3</metric>
    <metric>patients_speed</metric>
    <metric>patients_travel_time</metric>
    <metric>throughput</metric>
    <metric>stress</metric>
    <metric>redundancy</metric>
    <metric>entropy</metric>
    <metric>satisfaction</metric>
    <metric>energy</metric>
    <metric>teleCom</metric>
    <enumeratedValueSet variable="Egnatia">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="shuttle_station">
      <value value="&quot;en_route&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Lagkada">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="patient_density">
      <value value="1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="cong_area" first="0" step="2" last="20"/>
    <enumeratedValueSet variable="closed_road">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extra_congestion">
      <value value="0.4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="traffic_load">
      <value value="&quot;morning_rush&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="shuttle">
      <value value="true"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Dis-Cong Area SH-Ahp_Lagkada_AVRG" repetitions="10" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="100"/>
    <metric>mean [speed] of cars * 21.3</metric>
    <metric>patients_speed</metric>
    <metric>patients_travel_time</metric>
    <metric>throughput</metric>
    <metric>stress</metric>
    <metric>redundancy</metric>
    <metric>entropy</metric>
    <metric>satisfaction</metric>
    <metric>energy</metric>
    <metric>teleCom</metric>
    <enumeratedValueSet variable="Egnatia">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="shuttle_station">
      <value value="&quot;ahepa&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Lagkada">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="patient_density">
      <value value="1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="cong_area" first="0" step="2" last="20"/>
    <enumeratedValueSet variable="closed_road">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extra_congestion">
      <value value="0.4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="traffic_load">
      <value value="&quot;average&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="shuttle">
      <value value="true"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Dis-Cong Area SH-Ahp_Lagkada_MR" repetitions="10" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="100"/>
    <metric>mean [speed] of cars * 21.3</metric>
    <metric>patients_speed</metric>
    <metric>patients_travel_time</metric>
    <metric>throughput</metric>
    <metric>stress</metric>
    <metric>redundancy</metric>
    <metric>entropy</metric>
    <metric>satisfaction</metric>
    <metric>energy</metric>
    <metric>teleCom</metric>
    <enumeratedValueSet variable="Egnatia">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="shuttle_station">
      <value value="&quot;ahepa&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Lagkada">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="patient_density">
      <value value="1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="cong_area" first="0" step="2" last="20"/>
    <enumeratedValueSet variable="closed_road">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extra_congestion">
      <value value="0.4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="traffic_load">
      <value value="&quot;morning_rush&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="shuttle">
      <value value="true"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Dis-Cong Area SH-St_Lagkada_AVRG" repetitions="10" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="100"/>
    <metric>mean [speed] of cars * 21.3</metric>
    <metric>patients_speed</metric>
    <metric>patients_travel_time</metric>
    <metric>throughput</metric>
    <metric>stress</metric>
    <metric>redundancy</metric>
    <metric>entropy</metric>
    <metric>satisfaction</metric>
    <metric>energy</metric>
    <metric>teleCom</metric>
    <enumeratedValueSet variable="Egnatia">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="shuttle_station">
      <value value="&quot;station&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Lagkada">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="patient_density">
      <value value="1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="cong_area" first="0" step="2" last="20"/>
    <enumeratedValueSet variable="closed_road">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extra_congestion">
      <value value="0.4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="traffic_load">
      <value value="&quot;average&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="shuttle">
      <value value="true"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Dis-Cong Area SH-St_Lagkada_MR" repetitions="10" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="100"/>
    <metric>mean [speed] of cars * 21.3</metric>
    <metric>patients_speed</metric>
    <metric>patients_travel_time</metric>
    <metric>throughput</metric>
    <metric>stress</metric>
    <metric>redundancy</metric>
    <metric>entropy</metric>
    <metric>satisfaction</metric>
    <metric>energy</metric>
    <metric>teleCom</metric>
    <enumeratedValueSet variable="Egnatia">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="shuttle_station">
      <value value="&quot;station&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Lagkada">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="patient_density">
      <value value="1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="cong_area" first="0" step="2" last="20"/>
    <enumeratedValueSet variable="closed_road">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extra_congestion">
      <value value="0.4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="traffic_load">
      <value value="&quot;morning_rush&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="shuttle">
      <value value="true"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Dis-ClR SH-St_Lagkada_MR" repetitions="10" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="50"/>
    <metric>mean [speed] of cars * 21.3</metric>
    <metric>patients_speed</metric>
    <metric>patients_travel_time</metric>
    <metric>throughput</metric>
    <metric>stress</metric>
    <metric>redundancy</metric>
    <metric>entropy</metric>
    <metric>satisfaction</metric>
    <metric>energy</metric>
    <metric>teleCom</metric>
    <enumeratedValueSet variable="Egnatia">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="shuttle_station">
      <value value="&quot;station&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Lagkada">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="patient_density">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cong_area">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="closed_road">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extra_congestion">
      <value value="0.4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="traffic_load">
      <value value="&quot;morning_rush&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="shuttle">
      <value value="true"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Dis-ClR SH-EnR_Lagkada_MR" repetitions="10" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="50"/>
    <metric>mean [speed] of cars * 21.3</metric>
    <metric>patients_speed</metric>
    <metric>patients_travel_time</metric>
    <metric>throughput</metric>
    <metric>stress</metric>
    <metric>redundancy</metric>
    <metric>entropy</metric>
    <metric>satisfaction</metric>
    <metric>energy</metric>
    <metric>teleCom</metric>
    <enumeratedValueSet variable="Egnatia">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="shuttle_station">
      <value value="&quot;en_route&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Lagkada">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="patient_density">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cong_area">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="closed_road">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extra_congestion">
      <value value="0.4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="traffic_load">
      <value value="&quot;morning_rush&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="shuttle">
      <value value="true"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Dis-ClR SH-Ahp_Lagkada_MR" repetitions="10" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="50"/>
    <metric>mean [speed] of cars * 21.3</metric>
    <metric>patients_speed</metric>
    <metric>patients_travel_time</metric>
    <metric>throughput</metric>
    <metric>stress</metric>
    <metric>redundancy</metric>
    <metric>entropy</metric>
    <metric>satisfaction</metric>
    <metric>energy</metric>
    <metric>teleCom</metric>
    <enumeratedValueSet variable="Egnatia">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="shuttle_station">
      <value value="&quot;ahepa&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Lagkada">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="patient_density">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cong_area">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="closed_road">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extra_congestion">
      <value value="0.4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="traffic_load">
      <value value="&quot;morning_rush&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="shuttle">
      <value value="true"/>
    </enumeratedValueSet>
  </experiment>
</experiments>
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
