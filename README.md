# Energy Breakthrough

A collection of projects related to the [Energy Breakthrough](https://www.eb.org.au) vehicle our local primary school races.

The school runs 2 "Human Powered Vehicles" (pedal-powered reverse/tadpole trikes) that are based on an off-the-shelf kit frame and hand-made corflute/ziptie/tape shells.

Our (Ballarat Hackerspace) goals are basically to help improve the vehicles through a bunch of small individual projects that improve the quality-of-life of the kids using the vehicles, from better access to importanat maintenance areas to improved lighting/safety/comfort.

The project documentation for this project is in our wiki: [Energy Breakthrough Upgrades](https://gitlab.com/ballarat-hackerspace/services/workshop/-/wikis/group-projects/energy-breakthrough)

**This respository will be for pieces of the project that are ready to be shared openly for other teams to use as they wish.**

## Upgrade Kits

We are currently working on a few main upgrade kits for the vehicles, and when they are at a usable point all the related files/details will be put in this repo.

- **Custom ECU + Sensor Suite** - We have developed a fully custom electronics suite powered by an ESP32 on a custom PCB, with connectors letting you hook up sensors on the wheels and steering. This then lets you log (to micro-SD) or display (via an OLED dashboard) things such as wheel speed/RPM, steering angle, rider cadence, etc. Ultimately this will let you data-log sessions and compare them, build graphs, use them for training/education, and so on.

![EBT Vehicle ECU and Digital Dash](https://github.com/obsoletenerd/energy-breakthrough/blob/main/images/ebt-ecu.jpg?raw=true)

- **Centralised Electronics/Lighting** - Rather than using separate bicycle lights and bicycle horn and other accessories, each using their own batteries that need charging, we have built a custom central battery mount that takes a cheap off-the-shelf power-tool battery and then uses wiring looms to power all lights and accessories off a single battery. This lets you keep a spare charged battery to swap out in seconds via the removable rear hatch.

- **Removable Rear Hatch** - Modifies the back cover behind the rider to be removable with a quick-release latch, giving easy access to swap water bottles or get to the rear wheel and gears/brakes.

![EBT Vehicle Removable Rear Hatch](https://github.com/obsoletenerd/energy-breakthrough/blob/main/images/ebt-hatch.jpg?raw=true)

- **Under-Slung Steering Mod** - The standard steering on almost all the trikes used in EBT have their steering arms right next to the rider's legs, which then means the wheel covers are very intrusive on the rider's hands/legs and also cause lots of rubbing/friction when at full steering lock. We have developed a swap-in steering mod that moves all steering linkages underneath the chassis/seat and completely out of the way, as well as a matching new set of wheel covers that are very compact, giving the rider significantly more space.

## Tools and Side Projects

- **EBT Lap Timer** - We noticed at practice sessions that many teams use multiple iPads and the standard built-in "Timer" app to try and manage lap timing, with an iPad per vehicle, then writing down individual rider's times on paper which causes many missed laps and incomplete notes. We put together this single-page web app that lets someone manage timing for 2 vehicles, and stores the full session's lap times of all riders in both vehicles. The vehicle names and rider names are editable if you click on them, and the data table is downloadable as both CSV (to put into Excel) or JSON (for graphing and databases). All data is stored locally in the browser's LocalStorage and doesn't talk to any external servers/services. The [ebt-lap-timer.html](https://raw.githubusercontent.com/obsoletenerd/energy-breakthrough/refs/heads/main/ebt-lap-timer.html) file needs to be saved to any device (tablet, phone, laptop, anything with a modern web browser) and then opened in the browser.

![Energy Breakthrough Lap Timer](https://github.com/obsoletenerd/energy-breakthrough/blob/main/images/ebt-lap-timer.png?raw=true)
