-- locations.lua -- WhipFX edition
-- Where the fares wait, where they are going, and where the cabs stand on the rank.
-- Each entry is a vector4: x, y, z and the heading the ped faces.

Config.PickupLocations = {
    vector4(257.61, -380.57, 44.71, 340.5),
    vector4(-48.58, -790.12, 44.22, 340.5),
    vector4(240.06, -862.77, 29.73, 341.5),
    vector4(826.0, -1885.26, 29.32, 81.5),
    vector4(350.84, -1974.13, 24.52, 318.5),
    vector4(-229.11, -2043.16, 27.75, 233.5),
    vector4(-1053.23, -2716.2, 13.75, 329.5),
    vector4(-774.04, -1277.25, 5.15, 171.5),
    vector4(-1184.3, -1304.16, 5.24, 293.5),
    vector4(-1321.28, -833.8, 16.95, 140.5),
    vector4(-1613.99, -1015.82, 13.12, 342.5),
    vector4(-1392.74, -584.91, 30.24, 32.5),
    vector4(-515.19, -260.29, 35.53, 201.5),
    vector4(-760.84, -34.35, 37.83, 208.5),
    vector4(-1284.06, 297.52, 64.93, 148.5),
    vector4(-808.29, 828.88, 202.89, 200.5),
}

Config.DropLocations = {
    vector4(-1074.39, -266.64, 37.75, 117.5),
    vector4(-1412.07, -591.75, 30.38, 298.5),
    vector4(-679.9, -845.01, 23.98, 269.5),
    vector4(-158.05, -1565.3, 35.06, 139.5),
    vector4(442.09, -1684.33, 29.25, 320.5),
    vector4(1120.73, -957.31, 47.43, 289.5),
    vector4(1238.85, -377.73, 69.03, 70.5),
    vector4(922.24, -2224.03, 30.39, 354.5),
    vector4(1920.93, 3703.85, 32.63, 120.5),
    vector4(1662.55, 4876.71, 42.05, 185.5),
    vector4(-9.51, 6529.67, 31.37, 136.5),
    vector4(-3232.7, 1013.16, 12.09, 177.5),
    vector4(-1604.09, -401.66, 42.35, 321.5),
    vector4(-586.48, -255.96, 35.91, 210.5),
    vector4(23.66, -60.23, 63.62, 341.5),
    vector4(550.3, 172.55, 100.11, 339.5),
    vector4(-1048.55, -2540.58, 13.69, 148.5),
    vector4(-9.55, -544.0, 38.63, 87.5),
    vector4(-7.86, -258.22, 46.9, 68.5),
    vector4(-743.34, 817.81, 213.6, 219.5),
    vector4(218.34, 677.47, 189.26, 359.5),
    vector4(263.2, 1138.81, 221.75, 203.5),
    vector4(220.64, -1010.81, 29.22, 160.5),
}

-- The cab rank. A cab is brought out on the first spot that is clear.
Config.CabSpawns = {
    vector4(899.0837, -180.4414, 73.4115, 238.7553),
    vector4(897.1274, -183.3882, 73.3531, 238.4949),
    vector4(903.4929, -191.7166, 73.3883, 60.5255),
    vector4(904.9221, -188.7516, 73.4204, 60.5921),
    vector4(906.9083, -186.0502, 73.6249, 58.2671),
    vector4(908.7374, -183.2168, 73.7542, 57.1579),
    vector4(911.3865, -163.0307, 73.9763, 194.4093),
    vector4(913.5932, -159.4309, 74.3888, 193.9838),
    vector4(916.0979, -170.6549, 74.0125, 100.604),
    vector4(918.3217, -167.1944, 74.2036, 101.5165),
    vector4(920.6716, -163.4763, 74.4108, 96.2972),
}

-- The peds that hail a cab.
Config.NpcSkins = {
    'a_f_m_soucent_01', 'a_f_m_tourist_01', 'a_f_o_genstreet_01', 'a_f_o_ktown_01',
    'a_f_y_beach_01', 'a_f_y_bevhills_01', 'a_f_y_bevhills_02', 'a_f_y_business_01',
    'a_f_y_business_02', 'a_f_y_eastsa_01', 'a_f_y_fitness_01', 'a_f_y_hipster_01',
    'a_f_y_hipster_02', 'a_f_y_indian_01', 'a_f_y_runner_01', 'a_f_y_scdressy_01',
    'a_f_y_soucent_01', 'a_f_y_tourist_01', 'a_f_y_vinewood_01', 'a_f_y_vinewood_02',
    'a_m_m_afriamer_01', 'a_m_m_beach_01', 'a_m_m_bevhills_01', 'a_m_m_bevhills_02',
    'a_m_m_business_01', 'a_m_m_eastsa_01', 'a_m_m_farmer_01', 'a_m_m_genfat_01',
    'a_m_m_golfer_01', 'a_m_m_hasjew_01', 'a_m_m_indian_01', 'a_m_m_ktown_01',
    'a_m_m_malibu_01', 'a_m_m_paparazzi_01', 'a_m_m_polynesian_01', 'a_m_m_prolhost_01',
    'a_m_y_business_01', 'a_m_y_hipster_01', 'a_m_y_skater_01', 'a_m_y_stwhi_01',
}
