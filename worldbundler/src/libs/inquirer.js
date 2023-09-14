import inquirer from 'inquirer';

export const askForWorld = (worlds) => {
    const questions = [
      {
        type: 'checkbox',
        name: 'worlds',
        message: 'Select the world(s) you wish to bundle:',
        choices: worlds,
        default: []
      }
    ];
    return inquirer.prompt(questions);
}