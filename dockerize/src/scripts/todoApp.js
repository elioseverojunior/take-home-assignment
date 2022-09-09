//Instantiate and prepare the HTML template for a given item.
Vue.component("todo-item", {
    props: ["todo"],
    template: '<li>{{ todo.text }}<slot></slot></li>'
  });
  //Initialize the props associated with the components
  var todoList = new Vue({
    el: "#todoList",
    data: function() {
      return {
        newTodoText: "",
        todoList: [
          { id: 0, text: "item lol", done: false },
          { id: 1, text: "123", done: true }
        ],
        nextTodoId: 3
      };
    },
  
    methods: {
      //Push a new item to the list and prepare the component to recieve additional items.
      addItem: function() {
        if (!!this.newTodoText.trim()) {
          this.todoList.push({
            id: this.nextTodoId++,
            text: this.newTodoText,
            done: false
          });
        }
        this.newTodoText = "";
      },
      //Remove the selected item from the list
      removeItem: function() {
        this.todoList.pop();
      },
      //Toggle the state of the current todo item.
      todoDone: function(_todo) {
        _todo.done = !_todo.done;
      },
      reverse: function(value) {
        return value.slice().reverse();
      }
    }
  });

