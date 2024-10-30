[![](https://img.shields.io/badge/dynamic/json?color=orange&label=Factorio&query=downloads_count&suffix=%20downloads&url=https%3A%2F%2Fmods.factorio.com%2Fapi%2Fmods%2Fdeep-storage-unit&style=for-the-badge)](https://mods.factorio.com/mod/deep-storage-unit) [![](https://img.shields.io/badge/Discord-Community-blue?style=for-the-badge)](https://discord.gg/SAUq8hcZkq) [![](https://img.shields.io/github/issues/notnotmelon/deep-storage-unit?label=Bug%20Reports&style=for-the-badge)](https://github.com/notnotmelon/deep-storage-unit/issues) [![](https://img.shields.io/github/issues-pr/notnotmelon/deep-storage-unit?label=Pull%20Requests&style=for-the-badge)](https://github.com/notnotmelon/deep-storage-unit/pulls)

### Adds a container that can store an infinite amount of any item

Graphics from kaueNP
Compatible with all mods
Packed unit graphic from calcwizard's Packing Tape (MIT). https://mods.factorio.com/mod/packing-tape

---

### Packed units
Q: What happens when a unit is broken? Are my items lost?

A: Items are not lost. Items are "packed" inside the unit and are recovered when you place the unit back down.

![](https://i.imgur.com/EHCHCwE.png)

Warning: If a memory unit is destroyed (biters, nuke, or otherwise) then you will NOT get a packed unit and your items will be lost!

---

### Power
The memory unit requires power to function!
The power usage is equal to:
1MW + (ceil(item count / stack size) ^ 0.35) * 300kW
This can be changed in mod settings

If it runs out of power, then it will not accept any more items until it gets power again.

![](https://i.imgur.com/W2Qxm3F.png)

---

### Circuits
Memory units can connect to the circuit network! Simply attach a red or green wire to the circle on the top of the container.
This will read both the type and amount of whatever you have stored in the unit.

Circuit signals in Factorio can only go up to 2147483647. If you happen to have more items than this stored in a memory unit, then the signal will still only display as 2.1G.

---

### UPS
This mod is optimized. Should have a very minor impact on your UPS.

---

### Custom GUI
Memory units have a custom gui as of v1.3.0!

![](https://i.imgur.com/4kRuViS.png)

---

### Addon
Try the add-on mod! The fluid memory unit can store an infinite amount of any fluid.
https://mods.factorio.com/mod/fluid-memory-storage

---


### [> Check out my other mods! <](https://mods.factorio.com/user/notnotmelon)
