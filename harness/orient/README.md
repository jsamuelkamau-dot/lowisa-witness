# Which way up is the page?

Teachers photograph papers sideways and upside down. `orient_run.escript` asks Muse Spark which edge of each small
photo is the top of the printed page (`witness_photo:orient/3`, as shipped), and compares it with the first way of
asking (how many degrees to turn it). The photos are real exam pages and stay private; `truth.json` holds each one's
label.

[`results/orient-03nov.json`](results/orient-03nov.json), 4 papers × 3 runs: as shipped, **45 of 45** pages turned the
right way up (15 of 15 sideways); the first way, 44 of 45.
