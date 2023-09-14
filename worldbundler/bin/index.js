#!/usr/bin/env node

// #require = require('esm')(module);
// #require('../src/worldbundler.js').worldbundler(process.argv);

import {worldbundler} from "../src/worldbundler.js"

worldbundler(process.argv);
