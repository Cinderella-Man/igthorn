window.renderChart = (labels, symbol, data) => {
    if(["complete", "loaded", "interactive"].indexOf(document.readyState) >= 0){
        doRender(labels, symbol, data)
    } else {
        document.addEventListener("DOMContentLoaded", () => doRender(labels, symbol, data))
    }
}

let doRender = (labels, symbol, data) => {

    var chartData = {
        labels: labels,
        datasets: [{
            label: symbol,
            backgroundColor: 'rgb(255, 99, 132)',
            borderColor: 'rgb(255, 99, 132)',
            data: data,
            fill: false
        }]
    }

    var config = {
        // The type of chart we want to create
        type: 'line',
        // The data for our dataset
        data: chartData,
        // Configuration options go here
        options: {
            responsive: true,
            tooltips: {
                mode: 'index',
                intersect: false,
            },
            scales: {
                xAxes: [{
                    display: true,
                    scaleLabel: {
                        display: true,
                        labelString: 'Time'
                    }
                }],
                yAxes: [{
                    display: true,
                    scaleLabel: {
                        display: true,
                        labelString: 'Price'
                    }
                }]
            }
        }
    }

    if (window.chart !== undefined) {
        window.chart.update();
        return;
    }

    var ctx = document.getElementById('lineChart');
    window.chart = new Chart(ctx, config);
}

// var config = {
//     type: 'line',
//     data: {
//         labels: [],
//         datasets: [{
//             label: '',
//             backgroundColor: 'rgb(255, 99, 132)',
//             borderColor: 'rgb(255, 99, 132)',
//             data: [],
//             fill: false
//         }]
//     },
//     options: {
//         responsive: true,
//         tooltips: {
//             mode: 'index',
//             intersect: false,
//         },
//         scales: {
//             xAxes: [{
//                 display: true,
//                 scaleLabel: {
//                     display: true,
//                     labelString: 'Time'
//                 }
//             }],
//             yAxes: [{
//                 display: true,
//                 scaleLabel: {
//                     display: true,
//                     labelString: 'Price'
//                 }
//             }]
//         }
//     }
// };
//
// window.renderChart = (labels, symbol, data) => {
//     if (window.chart !== undefined) {
//
//         config.data.labels = labels;
//         config.data.datasets.label = symbol;
//         // config.data.datasets.data = data;
//         window.chart.update();
//
//     } else {
//         window.onload = function() {
//             var ctx = document.getElementById('lineChart');
//             config.data.labels = labels;
//             config.data.datasets.label = symbol;
//             // config.data.datasets.data = data;
//             window.chart = new Chart(ctx, config);
//         };
//     }
// };
