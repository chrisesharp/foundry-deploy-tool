"use strict";

import fs from "fs";
import { Level } from "level";
import tar from "tar";
import path from "path";
import clear from "clear";
import chalk from "chalk";
import figlet from "figlet";
import { askForWorld } from "./libs/inquirer.js";
import _ from "lodash";
import * as dotenv from 'dotenv';
import { exit } from "process";
dotenv.config();

const root = process.env.SOURCEDIR;
const worldsDir = root+"/FoundryVTT/Data/worlds";

function getDependencies(filepath) {
    let data = fs.readFileSync(filepath, 'utf8');
    let manifest = JSON.parse(data);
    let system = manifest.system;
    let deps = manifest.dependencies || [];
    let depDirs = (system) ? [`${root}/FoundryVTT/Data/systems/${system}`] : [];
    deps.forEach(dep => {
        if (dep.type && dep.name) {
            depDirs.push(`${root}/FoundryVTT/Data/${dep.type}s/${dep.name}`);
        }
    });
    return depDirs;
}

async function getSettings(world, depDirs) {
    const db = new Level(`${world}/data/settings`, { keyEncoding: 'utf8', valueEncoding: 'json' });
    const doc = (await db.values().all()).filter(e => e.key === 'core.moduleConfiguration').pop();
    const reg = (doc) ? JSON.parse(doc.value) : {};
    Object.entries(reg).forEach(([key,val]) => {
        if (val===true) {
            depDirs.push(`${root}/FoundryVTT/Data/modules/${key}`);
        }
    });
    return depDirs;
}

function getWorldDependencies(world) {
    let depDirs = getDependencies(world+"/world.json");
    return getSettings(world, depDirs);
}

async function collectAllDepedencies(world, depDirs) {
    let allDeps = [];
    depDirs.push(world);
    depDirs.push(`${root}/FoundryVTT/Config`);
    while (depDirs.length > 0) {
        let filepath = depDirs.pop();
        allDeps.push(filepath);
        let manifests = [];
        const manifest = `${filepath}/module.json`;
        if (fs.existsSync(manifest)) {
            manifests.push(manifest);
        }
        manifests.forEach(file => {
            let deps = getDependencies(file);
            deps.forEach(dep => {
                depDirs.push(dep)
            });
        });
    }
    return allDeps;
}

function buildBundle(dirs) {
    tar.c(
        {
           gzip: true,
           sync: true,
           cwd: root,
           follow: true,
           file: "foundry-upload.tgz"
        },
        dirs
    );
}

async function chooseWorld(worldsList) {
    const answer = await askForWorld(worldsList);
    if (answer.worlds.length) {
        const dirs = ['FoundryVTT/Data/common'];
        await Promise.all(answer.worlds.map(async (world) => {
            const chosenWorld = `${worldsDir}/${world}`;
            let depDirs = await getWorldDependencies(chosenWorld);
            let allDeps = await collectAllDepedencies(chosenWorld, depDirs);
            new Set(allDeps).forEach(dir => {
                dirs.push(path.relative(root, dir));
            });
        }));
        buildBundle(dirs);
    }
}

export async function worldbundler(args) {
    clear();
    console.log(
        chalk.blue(
            figlet.textSync("WorldBundler", {horizontalLayout: 'full'})
        )
    );
    console.log(`Using root:${root} and worldsDir:${worldsDir}`);
    
    const availableWorlds = _.without(fs.readdirSync(worldsDir), '.DS_Store', 'README.txt');
    if (availableWorlds.length) {
        try {
            await chooseWorld(availableWorlds);
        } catch (e) {
            console.error('PANIC!');
            console.error(e);
            exit(-1);
        }
        
    } else {
        console.log(chalk.red(`No worlds available in ${worldsDir} to bundle!`));
        exit(-1);
    }
}

