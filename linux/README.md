# Task 4: Linux
### Exercise Goals

* Copy your `app.yaml` from your second task to this folder with the name `script.yml`:
  * Replace the `image` value in your deployment by: `MY_NEW_IMAGE`
* Create a Bash Script named `automation.sh` to:
  * Build the `Dockerfile` you created on the first task;
  * After building your `Dockerfile`, your `Bash Script` is supposed to tag your image dinamically;
    * You can use hash, date, sequencial or any tagging approach you think it is good here;
  * Use your `script.yaml` as a template file to:
    * Create a new file called `new-app.yaml` replcaing the `MY_NEW_IMAGE` by your new image tag/name;
  * Use `kubectl` to show the difference between the current state in your `minikube` and your newly created `new-app.yaml`;

### Expected Output

Please, provide us with a file named `automation.sh` you created. Your `automation.sh` is supposed to:
* Build your `Dockerfile`;
* Tag your image dinacally;
* Create a new `new-app.yaml` file;
* Compare the `new-app.yaml` with your current state in your `minikube`;

Please, provide us with your `script.yml` and `new-app.yaml` files;

[Optional] You can also share screenshots of your progress.

### Next steps?

Once you complete this task, send us your assignment so we can evaluate it;
