import * as React from 'react';
import axios from "axios";

import MonkeyState from './MonkeyState'
import FormControl from '@mui/material/FormControl';
import InputLabel from '@mui/material/InputLabel';
import Select from '@mui/material/Select';
import MenuItem from '@mui/material/MenuItem';
import Grid from '@mui/material/Grid2';
import Button from '@mui/material/Button';
import Paper from '@mui/material/Paper';
import Box from '@mui/material/Box';
import FormGroup from '@mui/material/FormGroup';
import FormControlLabel from '@mui/material/FormControlLabel';
import Checkbox from '@mui/material/Checkbox';

class ErrorGc extends React.Component {
    constructor(props) {
        super(props);
        this.state = {
            gc_on: false
        };

        this.monkeyState = new MonkeyState(this, 'flags');

        this.handleInputChange = this.handleInputChange.bind(this);
        this.handleSubmit = this.handleSubmit.bind(this);
    }

    handleInputChange(event) {
        const target = event.target;
        const value = target.type === 'checkbox' ? target.checked : target.value;
        const name = target.name;

        this.setState({
            [name]: value
        });
    }

    async handleSubmit(event) {
        event.preventDefault();

        try {
            if (this.state.gc_on === false) {
                await axios.delete(`/monkey/flags/GC`);
            } else {
                await axios.post(`/monkey/flags/GC`);
            }
            this.monkeyState.fetchData();
        } catch (err) {
            console.log(err.message)
        }
    }

    render() {
        return (
            <form name="gc" onSubmit={this.handleSubmit}>
                <Grid container spacing={2}>
                    <FormGroup>
                        <FormControlLabel control={<Checkbox
                            name='gc_on'
                            checked={this.state.gc_on}
                            onChange={this.handleInputChange}
                            inputProps={{ 'aria-label': 'controlled' }}
                        />} label="ErrorGc" />
                    </FormGroup>
                    <Box width="100%"><Button variant="contained" data-transaction-name="ErrorGc" type="submit">Submit</Button></Box>
                    {this.monkeyState.render()}
                </Grid>
            </form>
        );
    }
}

export default ErrorGc;