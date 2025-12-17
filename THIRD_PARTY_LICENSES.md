# Third Party Licenses

This document lists all third-party software components included in the Videomancer SDK and their respective licenses.

---

## 1. Monocypher

**Version:** 4.0.2

**Location:** `third_party/monocypher/`

**Author:** Loup Vaillant

**Copyright:** Copyright (c) 2017-2019, Loup Vaillant

**License:** BSD-2-Clause OR CC0-1.0

**Website:** <https://monocypher.org>

**Purpose:** Cryptographic primitives for Ed25519 signature verification and BLAKE2b hashing

### BSD 2-Clause License

```text

Copyright (c) 2017-2019, Loup Vaillant

All rights reserved.

Redistribution and use in source and binary forms, with or without

modification, are permitted provided that the following conditions are

met:

1. Redistributions of source code must retain the above copyright

   notice, this list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright

   notice, this list of conditions and the following disclaimer in the

   documentation and/or other materials provided with the

   distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS

"AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT

LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR

A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT

HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,

SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT

LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,

DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY

THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT

(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE

OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

```

### CC0 1.0 Universal (Public Domain Dedication)

```text

Written in 2017-2019 by Loup Vaillant

To the extent possible under law, the author(s) have dedicated all copyright

and related neighboring rights to this software to the public domain

worldwide.  This software is distributed without any warranty.

You should have received a copy of the CC0 Public Domain Dedication along

with this software.  If not, see

<https://creativecommons.org/publicdomain/zero/1.0/>

```

**SPDX Identifier:** `BSD-2-Clause OR CC0-1.0`

---

## 2. SiliconBlue ICE40 Component Library

**Location:** `third_party/SiliconBlue/rtl/`

**Author:** jglong (SiliconBlue Technologies, Inc.)

**Copyright:** SiliconBlue Technologies, Inc. (now Lattice Semiconductor)

**License:** Proprietary (vendor-provided component library)

**Initial Release:** February 18, 2008

**Last Modified:** August 28, 2015

**Purpose:** VHDL component declarations for Lattice ICE40 FPGA primitives

**Note:** This file (`sb_ice40_components_syn.vhd`) is provided by Lattice Semiconductor as part of their ICE40 FPGA design tools. It contains component declarations for FPGA hardware primitives (LUTs, flip-flops, RAM, PLLs, I/O buffers, etc.) required for FPGA synthesis. The file is typically distributed with Lattice's development tools and is used for simulation and synthesis purposes.

**Revision History:**

- Aug 06, 2015: Correct SB_IO_I3C pin direction (Jayakumar Sundaram)

- Aug 07, 2015: Add SB_DELAY_50NS and SB_FILTER_50NS (Brian Tai)

- Aug 18, 2015: Added SCL_INPUT_FILTERED attribute to SB_I2C (Jayakumar Sundaram)

- Aug 28, 2015: Remove primitives SB_DELAY_50NS and SB_FILTER_50NS (Brian Tai)

**Usage:** This component library is essential for FPGA development targeting Lattice ICE40 devices. It is not modified by this project and retains its original header and authorship information.

---

## Summary Table

| Component | Version | License | Purpose |

|-----------|---------|---------|---------|

| Monocypher | 4.0.2 | BSD-2-Clause OR CC0-1.0 | Cryptographic operations (Ed25519, BLAKE2b-256) |

| SiliconBlue ICE40 Components | 2015-08-28 | Proprietary (Lattice) | FPGA primitive declarations for ICE40 synthesis |

---

## License Compatibility

All third-party components are compatible with the Videomancer SDK's GPL-3.0-only license:

- **Monocypher (BSD-2-Clause OR CC0-1.0):** Both BSD-2-Clause and CC0-1.0 are permissive licenses compatible with GPL-3.0. The dual-license allows users to choose whichever is more convenient.

- **SiliconBlue ICE40 Components (Proprietary):** Vendor-provided FPGA component libraries are standard development tools distributed with FPGA toolchains. Their inclusion is necessary for FPGA development and does not impose licensing restrictions on the overall project. These components define hardware interfaces and are not linked or distributed with compiled software.

---

## Additional Information

### Monocypher

Monocypher is a cryptographic library that focuses on simplicity and correctness. It provides:

- **Ed25519:** Public-key signature verification

- **BLAKE2b:** Cryptographic hash function (SHA-256 equivalent security)

- **Secure memory operations:** Constant-time comparison and secure wiping

For more information, see: <https://monocypher.org>

### SiliconBlue/Lattice ICE40

Lattice Semiconductor's ICE40 FPGA family is used in Videomancer hardware. The component library enables HDL synthesis targeting these devices. For FPGA development information, see: <https://www.latticesemi.com/iCE40>

---

## Updating This Document

When adding new third-party components:

1. Add a new numbered section with complete attribution

2. Include version, copyright, license, and purpose

3. Provide full license text

4. Update the summary table

5. Document license compatibility with GPL-3.0

